class Refusal(Exception):
    pass


class Internal(Exception):
    pass


class Infrastructural(Exception):
    pass


class Stall(Exception):
    def __init__(self, unit_class, reason, findings=None, next_act=None):
        Exception.__init__(self, reason)
        self.unit_class = unit_class
        self.findings = findings or []
        self.next_act = next_act
