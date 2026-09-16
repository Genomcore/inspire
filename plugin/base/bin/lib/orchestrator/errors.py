"""The four ways this process stops: a refusal, an internal defect, an
infrastructural failure nobody judged, and a unit that cannot go on."""


class Refusal(Exception):
    """t=0 said no. Nothing was spawned, and nothing of the operator's moved."""


class Internal(Exception):
    """A tool answered outside its documented exit codes."""


class Infrastructural(Exception):
    """A phase failed without anyone judging it — a crash, an empty emission, a
    recipe step that would not run. Nobody rejected the persona."""


class Stall(Exception):
    def __init__(self, unit_class, reason, findings=None, next_act=None):
        Exception.__init__(self, reason)
        self.unit_class = unit_class
        self.findings = findings or []
        self.next_act = next_act
