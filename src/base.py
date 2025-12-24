import os

import law


class BaseTask(law.Task):
    """
    Base task which provides some convenience methods
    """

    version = law.Parameter(default="dev")

    def store_parts(self):
        outdir = os.getenv("TEMPLATE_OUT")
        if not outdir:
            raise RuntimeError("TEMPLATE_OUT not set. Run: source setup.sh")    
        task_name = self.__class__.__name__
        return (
            outdir,
            f"version_{self.version}",
            task_name,
        )

    def local_path(self, *path):
        sp = self.store_parts()
        sp += path
        return os.path.join(*(str(p) for p in sp))

    def local_target(self, *path, **kwargs):
        return law.LocalFileTarget(self.local_path(*path), **kwargs)

    def local_directory_target(self, *path, **kwargs):
        return law.LocalDirectoryTarget(self.local_path(*path), **kwargs)


class ParameterMixin(law.Task):
    """
    Demonstrative mixin to add common parameters to tasks
    """

    parameter = law.Parameter(
        default="Parameter",
        description="A demonstration parameter",
    )

    def store_parts(self):
        sp = super().store_parts()
        return sp + (f"parameter_{self.parameter}",)
