# Miking Jupyter

The goals of the Miking Jupyter project are to:

* Integrate Miking with the [Jupyter](https://jupyter.org/)
  environment by providing a Miking kernel for Jupyter.

* Provide seamless integration with Python from Miking languages,
  meaning that Miking functions can call Python code and the reverse.

* Support syntax highlighting and code editor customization for arbitrary DSLs designed in Miking.

* Support visualization within Jupyter notebooks.

## MCore Jupyter Kernel

This repository contains a fully featured
[Jupyter](https://jupyter.org/) kernel for MCore which is based on the
`mi` bootstrap interpreter. It is focused on enabling a large amount
of interoperability between MCore and Python.

### Repository structure

This section describes where to find the main source files of the repository
and their purpose.

- The actual kernel implementation can be found in [kernel.ml](src/kernel.ml).
- [mpl_backend.py](src/mpl_backend.py) contains a `matplotlib` backend for
  displaying plots produced by `matplotlib` inline in Jupyter Notebooks.
- [mcore-syntax/main.js](src/mcore-syntax/main.js) contains a Notebook extension
  for MCore syntax highlighting.
- The project is built and installed using the [make.sh](./make.sh) script.

### Jupyter basics

[Jupyter](https://jupyter.org/) provides an ecosystem for writing, documenting
and visualizing code in an interactive way. The _Jupyter Notebook_ is a
literate programming environment for this purpose. Notebooks can contain text,
executable code, display images and more. Notebooks provide support for many languages
by using language-specific _kernels_, which take care of executing the user's
code and producing output for the notebook to display.

To get a quick introduction on how to use Jupyter Notebooks in
general, check out
[this tutorial](https://mybinder.org/v2/gh/ipython/ipython-in-depth/master?filepath=binder/Index.ipynb).
https://jupyter.org/ also provides more helpful links and information.

This README will explain how to get started with Jupyter Notebooks for MCore,
and go through all the functionality of the Jupyter MCore kernel. Once you have
installed the kernel in the next section, there is also an interactive notebook
demonstrating MCore and the kernel's capabilities at `MCoreJupyter.ipynb`.

### Getting started

Before using the Jupyter kernel you need to install some dependencies.
The Jupyter kernel requires the Miking bootstrap interpreter,
and the `pyml` Python bindings for OCaml.

First, install `pyml` to make sure `boot` is built with Python support:

```bash
opam install pyml
```

For more details and troubleshooting when installing `pyml`, see the main repository's
[README.md](https://github.com/miking-lang/miking/blob/develop/README.md#Python).
Then, install the `boot` package. This can be done using `opam` with the following:

```bash
opam pin add boot https://github.com/miking-lang/miking.git#develop
opam install boot
```

Next, you will need to have Jupyter itself installed.
To install Jupyter using `pip`, run the following command:

```bash
pip install jupyter
```

Finally, the OCaml package `jupyter-kernel` is needed. This package depends on
the `zeromq` C library, so make sure to install it on your system first. On
Debian-based Linux distributions, this can be done with:

```bash
sudo apt-get install libzmq3-dev
```

On macOS, it can be installed using brew:

```bash
brew install zeromq
```

Once this is done, `jupyter-kernel` can be installed through `opam`, using:

```bash
opam install jupyter-kernel
```

Finally, to install the Jupyter kernel, use the `make.sh` script
(note that you may have to run `chmod +x make.sh` the first time to make the
script executable):

```bash
./make.sh install
```

You are now ready to start using the kernel. For example, to start a new Jupyter
Notebook using the MCore kernel, run `jupyter notebook`
and select the `MCore` kernel when creating a new notebook.

*Note that `$HOME/.local/bin` must be included in your PATH. This should be
done by default on most Linux distributions.*

### Functionality

This section describes all functionality that is supported by the MCore
Jupyter kernel.

#### Basic code cells

The Jupyter kernel allows writing and executing code in an interactive manner.
For example, to print the typical 'Hello world!' message, try inputting the following
into a cell and executing it using `Shift-Enter`.

```ocaml
print "Hello world!"
```

The notebook provides syntax highlighting and autocompletion. To trigger the
autocompletion, press `Tab` after inputting part of a word. The completions
include both builtin functions and user-defined names.

#### Now you're playing with Python

The MCore kernel also allows executing Python code and interacting with it from
MCore. Use the special directive `%%python` at the top of a cell to evaluate
Python code.

For example, the following cell defines a Python function `foo` and calls it.

```python
%%python
def foo(x):
  print("foo"+x)

foo("bar")
```

Running the cell will print `foobar`, as one might expect.

You can call the functions you have defined in Python cells in normal MCore
cells by using the Python intrinsics (for more information on these, see
[README.md](https://github.com/miking-lang/miking/blob/develop/README.md#Python) or the example notebook). A user-defined function can
be called by importing and using the Python module `__main__`. For example,
consider the following cell:

```ocaml
let m = pyimport "__main__" in
let x = "bar" in
pycall m "foo" (x,)
```

This cell will call the Python function `foo` defined above, again printing
`foobar` as expected.

#### Plotting graphs

It is possible to plot graphs using the Python library `matplotlib`.
The Jupyter kernel offers integration with `matplotlib` to display plots
directly in a notebook.

To use this functionality, first make sure that `matplotlib` is installed (if
not, you can install it using `pip`). Now, when you use `matplotlib`'s plot
functions in a notebook cell, the plots will be displayed as part of the cell's
output. For example, you can try running the following in a cell:

```ocaml
let plt = pyimport "matplotlib.pyplot"
let x = [1,2,4,8]
let _ = pycall plt "plot" (x,)
```

While this example uses the Python intrinsics, running the plot code directly in
a Python cell would of course also work.

#### IPM visualization

It is also possible to display visualizations of programmatic models from
[The Miking Interactive Programmatic Modeling (IPM) Environment](https://github.com/miking-lang/miking-ipm).

Start by following the installation instructions at
https://github.com/miking-lang/miking-ipm to install the IPM visualization
server. Make sure that the `ipm-server` executable is available in `PATH` and
that you are able to run it from the command line.

To visualize a model, use the `%%visualize` directive. The visualization server
will be started in the background the first time the directive is used.

Use `%%visualize` in a cell whose output is a string representation of the
relevant model; the IPM repo provides the function `formatModels` for this
purpose. For instance, supposing `model` is a predefined DFA model and that the
IPM visualization functions have been imported, running the following code in a
cell would produce a visualization of the DFA:

```ocaml
%%visualize
formatModels [model]
```

For a more complete example, see the example interactive notebook.

### Interactive notebook

If you followed the installation instructions above, you can try out the
interactive example notebook, by running `jupyter notebook` in the root
directory of the repository and opening the file `MCoreJupyter.ipynb` from the
Jupyter Notebook interface. The notebook features many examples, including MCore
basics and the Python intrinsics, demonstrating the full capabilities of the
MCore Jupyter kernel.

## MIT License

Copyright (c) 2020 David Broman

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
