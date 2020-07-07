from ipykernel.kernelbase import Kernel
from pexpect import replwrap


class McoreKernel(Kernel):
    implementation = 'IMCore'
    implementation_version = '0.1'
    language = 'MCore'
    language_version = '0.1'
    language_info = {
        'name': 'MCore',
        'mimetype': 'text/plain',
        'file_extension': '.mc',
        'codemirror_mode': 'ocaml'
    }
    banner = """The core language of Miking - a meta language system
for creating embedded domain-specific and general-purpose languages"""

    def __init__(self, **kwargs):
        Kernel.__init__(self, **kwargs)
        self.wrapper = replwrap.REPLWrapper("mi repl --no-line-edit", ">> ", None, continuation_prompt=" | ")

    def do_execute(self, code, silent, store_history=True, user_expressions=None,
                   allow_stdin=False):
        output = self.wrapper.run_command(":{\n" + code + "\n:}")
        if not silent:
            stream_content = {'name': 'stdout', 'text': output}
            self.send_response(self.iopub_socket, 'stream', stream_content)

        return {'status': 'ok',
                # The base class increments the execution count
                'execution_count': self.execution_count,
                'payload': [],
                'user_expressions': {}
                }


if __name__ == '__main__':
    from ipykernel.kernelapp import IPKernelApp
    IPKernelApp.launch_instance(kernel_class=McoreKernel)
