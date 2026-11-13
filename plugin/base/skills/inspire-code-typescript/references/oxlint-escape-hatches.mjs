const PLUGIN = "escape-hatches";
const DIRECTIVE = /^\s*(?:oxlint|eslint)-disable(?:-next-line|-line)?(?=\s|$)(?<body>[^]*)$/;

const ruleName = (rule) => rule.split("/").pop();

function directives(sourceCode) {
  return sourceCode.getAllComments().flatMap((comment) => {
    const match = DIRECTIVE.exec(comment.value);
    if (!match) return [];
    const [list, ...reason] = match.groups.body.split("--");
    const rules = list
      .split(",")
      .map((rule) => rule.trim())
      .filter(Boolean);
    return [{ comment, rules, reason: reason.join("--").trim() }];
  });
}

const requireReason = {
  meta: { type: "problem" },
  create(context) {
    return {
      Program() {
        for (const { comment, rules, reason } of directives(context.sourceCode)) {
          if (rules.length === 0) {
            context.report({ loc: comment.loc, message: "A disable directive must name the rules it disables." });
          } else if (!reason) {
            context.report({ loc: comment.loc, message: "A disable directive must say why, after `--`." });
          }
        }
      },
    };
  },
};

const noRestrictedDisable = {
  meta: { type: "problem", schema: [{ type: "array", items: { type: "string" } }] },
  create(context) {
    const restricted = new Set((context.options[0] ?? []).map(ruleName));
    const isRestricted = (rule) => rule.startsWith(`${PLUGIN}/`) || restricted.has(ruleName(rule));
    return {
      Program() {
        for (const { comment, rules } of directives(context.sourceCode)) {
          for (const rule of rules.filter(isRestricted)) {
            context.report({ loc: comment.loc, message: `\`${rule}\` may not be disabled inline.` });
          }
        }
      },
    };
  },
};

const noDoubleCast = {
  meta: { type: "problem" },
  create(context) {
    return {
      TSAsExpression(node) {
        const inner = node.expression;
        if (inner.type === "TSAsExpression" && inner.typeAnnotation.type === "TSUnknownKeyword") {
          context.report({ node, message: "`as unknown as` casts past the type checker." });
        }
      },
    };
  },
};

export default {
  meta: { name: PLUGIN },
  rules: {
    "require-reason": requireReason,
    "no-restricted-disable": noRestrictedDisable,
    "no-double-cast": noDoubleCast,
  },
};
