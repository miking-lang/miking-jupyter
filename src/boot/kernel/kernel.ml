open Jupyter_kernel
open Repl
open Eval

let current_output = ref (BatIO.output_string ())
let other_actions = ref []

let text_data_of_string str =
  Client.Kernel.mime ~ty:"text/plain" str

let kernel_output_string str = BatIO.nwrite !current_output str
let kernel_output_ustring ustr = ustr |> Ustring.to_utf8 |> kernel_output_string

let python_init = Py.initialize ~version:3 ()
let ocaml_module = Py.Import.add_module "ocaml"

(* Set Python's sys.stdout to our own ocaml function to handle Python prints *)
let init_py_print () =
  let py_ocaml_print args =
    kernel_output_string (Py.String.to_string args.(0));
    Py.none
  in
  Py.Module.set_function ocaml_module "ocaml_print" py_ocaml_print;
  ignore @@ Py.Run.eval ~start:Py.File "
import sys
from ocaml import ocaml_print
class OCamlPrint:
    def write(self, str):
        ocaml_print(str)

sys.stdout = OCamlPrint()"

let init_py_mpl () =
  ignore @@ Py.Run.eval ~start:Py.File "
import os
os.environ['MPLBACKEND']='module://src.boot.kernel.mpl_backend'";
  let py_ocaml_show args =
    let data = Py.String.to_string args.(0) in
    other_actions := Client.Kernel.mime ~base64:true ~ty:"image/png" data :: !other_actions;
    Py.none
  in
  Py.Module.set_function ocaml_module "ocaml_show" py_ocaml_show

let init () =
  initialize_envs ();
  Mexpr.program_output := kernel_output_ustring;
  Py.Module.set_function ocaml_module "after_exec" (fun _ -> Py.none);
  init_py_print ();
  init_py_mpl ();
  Lwt.return ()

let get_python code =
  let python_indicator, content =
    try BatString.split code ~by:"\n"
    with Not_found -> ("", code)
  in
  match python_indicator with
  | "%%python" -> Some content
  | _ -> None

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
  if is_expr expr then
    begin
      ignore @@ Py.Run.eval ~start:Py.File statements;
      Py.Run.eval expr
    end
  else
    Py.Run.eval ~start:Py.File code

let exec ~count code =
  try
    let result =
      match get_python code with
      | Some content ->
        let py_val = eval_python content in
        if py_val = Py.none then
          None
        else
          Some(Py.Object.to_string py_val)
      | None ->
        parse_prog_or_mexpr (Printf.sprintf "In [%d]" count) code
        |> repl_eval_ast
        |> repl_format
        |> Option.map (Ustring.to_utf8)
    in
    ignore @@ Py.Module.get_function ocaml_module "after_exec" [||];
    let new_actions =
      match BatIO.close_out !current_output with
      | "" -> !other_actions
      | s -> text_data_of_string s :: !other_actions
    in
    let actions = List.rev new_actions in
    current_output := BatIO.output_string ();
    other_actions := [];
    Lwt.return (Ok { Client.Kernel.msg=result
                   ; Client.Kernel.actions=actions})
  with e -> Lwt.return (Error (error_to_ustring e |> Ustring.to_utf8))

let complete ~pos str =
  let start_pos, completions = get_completions str pos in
  Lwt.return { Client.Kernel.completion_matches = completions
             ; Client.Kernel.completion_start = start_pos
             ; Client.Kernel.completion_end = pos}

let main =
  let mcore_kernel =
    Client.Kernel.make
      ~language:"MCore"
      ~language_version:[0; 1]
      ~file_extension:".mc"
      ~codemirror_mode:"mcore"
      ~banner:"The core language of Miking - a meta language system
for creating embedded domain-specific and general-purpose languages"
      ~init:init
      ~exec:exec
      ~complete:complete
      () in
      let config = Client_main.mk_config ~usage:"Usage: kernel --connection-file {connection_file}" () in
      Lwt_main.run (Client_main.main ~config:config ~kernel:mcore_kernel)
