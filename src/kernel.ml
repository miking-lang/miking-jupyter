(* kernel.ml
 *
 * This file contains a Jupyter kernel for the Miking core language, MCore. In
 * the future, it should also provide automatic support for DSLs defined using
 * the Miking system.
 *
 * The implementation relies on the [Jupyter_kernel] package, which provides the
 * functions [Client.Kernel.make] for defining a Jupyter kernel, and
 * [Client_main.main] for running such a kernel.
 *
 * The main functions of the implementation are [init], [exec] and [complete].
 *)

open Jupyter_kernel
open Boot.Repl
open Boot.Eval
open Lwt.Infix
open Printf

let to_utf8 = Boot.Ustring.to_utf8

(* [current_output] is a buffer for capturing prints from the Mcore interpreter
  and Python process *)
let current_output = ref (BatIO.output_string ())

(* [rich_results] stores rich results from code cells such as plots *)
let rich_results = ref []

(* Globals for handling IPM visualization *)
let ipm_port = ref 0
let ipm_start_signal = Lwt_mvar.create_empty ()
let ipm_start_response = Lwt_mvar.create_empty ()

let peek_mvar mvar =
  Lwt_mvar.take mvar >>= fun x ->
  Lwt_mvar.put mvar x >>= fun _ ->
  Lwt.return x

let kernel_output_string str = BatIO.nwrite !current_output str
let kernel_output_ustring ustr = ustr |> to_utf8 |> kernel_output_string

let _ = Py.initialize ~version:3 ()
let ocaml_module = Py.Import.add_module "_mcore_kernel"

(* Set Python's sys.stdout to our own ocaml function to handle Python prints *)
let init_py_print () =
  let py_ocaml_print args =
    kernel_output_string (Py.String.to_string args.(0));
    Py.none
  in
  Py.Module.set_function ocaml_module "ocaml_print" py_ocaml_print;
  ignore @@ Py.Run.eval ~start:Py.File "
import sys
from _mcore_kernel import ocaml_print
class OCamlPrint:
    def write(self, str):
        ocaml_print(str)

sys.stdout = OCamlPrint()"

(* Set the PYTHONPATH to include our matplotlib backend, and set the MPLBACKEND
  environment variable to point to it *)
let init_py_mpl () =
  ignore @@ Py.Run.eval ~start:Py.File "
import os, sys
sys.path.append(os.path.expanduser('~') + '/.local/lib/mcore/kernel')
os.environ['MPLBACKEND']='module://mpl_backend'";
  let py_ocaml_show args =
    let data = Py.String.to_string args.(0) in
    rich_results := Client.Kernel.mime ~base64:true ~ty:"image/png" data :: !rich_results;
    Py.none
  in
  Py.Module.set_function ocaml_module "ocaml_show" py_ocaml_show

(* Initialize everything needed for running the kernel. In particular,
  the [program_output] function is modified to make MCore prints be displayed
  by the frontend, and the [after_exec] hook is introduced in the Python
  environment to allow matplotlib to trigger plot redrawing after a cell has
  been executed.
  *)
let init () =
  initialize_envs ();
  Boot.Mexpr.program_output := kernel_output_ustring;
  Py.Module.set_function ocaml_module "after_exec" (fun _ -> Py.none);
  init_py_print ();
  init_py_mpl ();
  Lwt.return ()

let parse_and_eval count code =
  parse_prog_or_mexpr (sprintf "In [%d]" count) code
  |> repl_eval_ast

(* Run visualization of a cell with %%visualize directive.
  Uses [ipm_start_signal] to start the server the first time and
  [ipm_start_response] to keep track of whether the server was started
  successfully.
  Sends the output of the cell to the visualization server, then embeds the
  webpage served by the IPM server into the output cell.
  *)
let visualize_model count code =
  let raise_error = Boot.Msg.raise_error in
  (if Lwt_mvar.is_empty ipm_start_signal then
    Lwt_mvar.put ipm_start_signal true
  else
    Lwt.return ())
  >>= fun _ ->
  peek_mvar ipm_start_response >>= fun visualization_supported ->
  if visualization_supported then
    let seq2string tm =
      let open Boot.Ast in
      match tm with
      | TmSeq(fi, seq) -> tmseq2ustring fi seq |> to_utf8
      | _ -> raise_error (tm_info tm) "Expected a string to visualize, but got other term"
    in
    let model_str = parse_and_eval count code |> seq2string in
    let iframe_str = sprintf {|<embed src="http://localhost:%d/" width="100%%" height="400"</embed>|} !ipm_port in
    let uri = Uri.of_string (sprintf "http://localhost:%d/js/data-source.json" !ipm_port) in
    let body = Cohttp_lwt.Body.of_string model_str in
    rich_results := Client.Kernel.mime ~ty:"text/html" iframe_str :: !rich_results;
    Lwt.catch
      (fun () -> Cohttp_lwt_unix.Client.post ~body uri >|= fun _ -> None)
      (function
        | Unix.Unix_error (ECONNREFUSED,_,_) ->
          raise_error NoInfo "Failed to contact the visualization server. Make sure that it was installed correctly"
        | e -> Lwt.fail e)
  else
    raise_error NoInfo "The visualization server could not be started, running without support for %%visualize"

let is_expr pycode =
  try
    ignore @@ Py.compile ~source:pycode ~filename:"" `Eval;
    true
  with _ -> false

let eval_python code =
  let statements, expr =
    try BatString.rsplit code ~by:"\n"
    with Not_found -> ("", code)
  in
  let py_val = if is_expr expr then
    (ignore @@ Py.Run.eval ~start:Py.File statements;
    Py.Run.eval expr)
  else
    Py.Run.eval ~start:Py.File code
  in
  if py_val = Py.none then
    None
  else
    Some (Py.Object.to_string py_val)

let evaluate_cell count code =
  let magic_indicator, content =
    try BatString.split code ~by:"\n"
    with Not_found -> ("", code)
  in
  match magic_indicator with
   | "%%visualize" -> visualize_model count content
   | _ -> Lwt.return @@
     match magic_indicator with
     | "%%python" -> eval_python content
     | _ ->
       parse_and_eval count code
       |> repl_format
       |> Option.map to_utf8

(* Execute [code] from cell number [count] and return the results. After
  evaluating the code, run the [after_exec] hook and empty the [rich_results]
  list. *)
let exec ~count code =
  let result =
    Lwt.catch
      (fun () ->
        evaluate_cell count code
        >|= Result.ok)
      (fun e ->
        error_to_ustring e
        |> to_utf8
        |> Result.error
        |> Lwt.return)
  in
  let ok_message result =
    ignore @@ Py.Module.get_function ocaml_module "after_exec" [||];
    let new_results =
      match BatIO.close_out !current_output with
      | "" -> !rich_results
      | s -> Client.Kernel.mime ~ty:"text/plain" s :: !rich_results
    in
    let actions = List.rev new_results in
    current_output := BatIO.output_string ();
    rich_results := [];
    { Client.Kernel.msg=result
    ; Client.Kernel.actions=actions }
  in
  result >|= Result.map ok_message

(* Produce completions for [str] with cursor at position [pos] *)
let complete ~pos str =
  let start_pos, completions = get_completions str pos in
  Lwt.return { Client.Kernel.completion_matches = completions
             ; Client.Kernel.completion_start = start_pos
             ; Client.Kernel.completion_end = pos }

let executable_in_path name =
  let path = String.split_on_char ':' (Option.default "" (Sys.getenv_opt "PATH")) in
  let name_in_dir dir =
    try Unix.access (sprintf "%s/%s" dir name) [ X_OK ]; true
    with _ -> false
  in
  List.exists name_in_dir path

let get_open_port start_port max_port =
  let open Unix in
  let localhost port = ADDR_INET (inet_addr_loopback, port) in
  let sock = socket PF_INET SOCK_STREAM 0 in
  let rec iterate_ports port =
    if port < max_port then
      try
        bind sock (localhost port);
        close sock;
        Some port
      with Unix_error (EADDRINUSE,_,_) ->
        iterate_ports (port + 1)
    else
      None
  in iterate_ports start_port

(* Await a value in [ipm_start_signal]; if the value is true, then start the IPM
 server, else return. *)
let run_ipm () =
  peek_mvar ipm_start_signal >>= fun try_to_start ->
    if try_to_start then
      if executable_in_path "ipm-server" then
        match get_open_port 3030 3130 with
        | Some p ->
            ipm_port := p;
            Lwt_process.exec ("", [|"ipm-server"; "--no-file"; "-p"; string_of_int p|]) >|= ignore
            <&> (Lwt_unix.sleep 0.5 >>= fun _ ->
                 Lwt_mvar.put ipm_start_response true)
        | None ->
           prerr_endline "Failed to get open port for server...";
           Lwt_mvar.put ipm_start_response false
      else
        (prerr_endline "Failed to find server executable in path...";
         Lwt_mvar.put ipm_start_response false)
    else
      Lwt.return ()

let run_kernel () =
  let mcore_kernel =
    Client.Kernel.make
      ~language:"MCore"
      ~language_version:[0; 1]
      ~file_extension:".mc"
      ~codemirror_mode:"mcore"
      ~banner:"The core language of Miking - a meta language system
for creating embedded domain-specific and general-purpose languages"
      ~init
      ~exec
      ~complete
      ()
  in
  let config = Client_main.mk_config
                 ~usage:"Usage: kernel --connection-file CONNECTION_FILE" () in
  Client_main.main ~config ~kernel:mcore_kernel >>= fun _ ->
  if Lwt_mvar.is_empty ipm_start_signal then
    Lwt_mvar.put ipm_start_signal false
  else
    Lwt.return ()

(* Run the kernel and IPM server concurrently, with the IPM server
  awaiting a signal on [ipm_start_signal] to start. *)
let main = Lwt_main.run (run_kernel () <&> run_ipm ())
