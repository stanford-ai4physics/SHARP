from src.base import BaseTask


class ExampleTask(BaseTask):
    """
    An example task that extends BaseTask
    """

    def requires(self):
        return []

    def output(self):
        return self.local_target("output.txt")
    
    def run(self):
        self.output().touch()