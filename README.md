# Miking Jupyter

The goals of the Miking Jupyter project are to:

* Integrate Miking with the [Jupyter](https://jupyter.org/)
  environment by providing a Miking kernel for Jupyter.

* Provide seamless integration with Python from Miking languages,
  meaning that Miking functions can call Python code and the reverse.

* Support syntax highlighting and code editor customization for arbitrary DSLs designed in Miking.

* Support visualization within Jupyter notebooks.

## Jupyter Kernel

Currently, a simple Jupyter kernel extending the main IPython kernel is
available in [`mcore_kernel`](./mcore_kernel). It depends on the MCore REPL to
execute code from the user; presently, it simply feeds the cell contents into
the REPL and then displays the results.

### Dependencies and setup

To try out the kernel, you will need the following dependencies:

- [Jupyter](https://jupyter.org/) and [IPython](https://ipython.org/).

  Installation using pip:
  `pip install ipython jupyter`

- The package [pexpect](https://pypi.org/project/pexpect/) is used to control
  the REPL process.

  Installation using pip:
  `pip install pexpect`

- The Miking bootstrap interpreter REPL. This should be available at the
  `develop` branch of the
  [main Miking repo](https://github.com/miking-lang/miking). Note that the
  bootstrap interpreter needs to be available in `PATH` under the name `mi`.

### Getting started

Make sure you have all dependencies installed, and that the MCore bootstrap
interpreter `mi` is in your `PATH`. Then, run the following command from the
project root directory to install the kernel.

```
jupyter kernelspec install mcore_kernel/
```

The kernel should now be known to Jupyter. To run it, **make sure you are in
the project root**, so that Python can locate the kernel module as
`mcore_kernel.kernel`. In the future, the kernel will be packaged so that Python
can find it from any directory.

You should now be able to run the kernel. For instance, to start a notebook,
run

```
jupyter notebook
```

and open a new notebook, selecting the `MCore` kernel. To test things out
quickly, check out the [`Example.ipynb`](./Example.ipynb) notebook.

For more information on how to use a Jupyter notebook, check out their website
or this
[tutorial](https://mybinder.org/v2/gh/ipython/ipython-in-depth/master?filepath=binder/Index.ipynb)
at https://mybinder.org/

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
