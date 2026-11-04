function consider(p, tok, kind, k) {
  if (p == 0 || tok == "") return
  if (best == 0 || p < best || (p == best && length(tok) > length(btok))) {
    best = p; btok = tok; bkind = kind; bk = k
  }
}

function push(kind, k) {
  sp++; st[sp] = kind; sk[sp] = k; depth[sp] = 0
}

function emit_comment(line_no, body) {
  gsub(/\t/, " ", body)
  print FILENAME "\t" line_no "\t" body >> comment_out
}

NR == FNR {
  split($0, f, "\t")
  if (f[1] == "line") { nl++; lo[nl] = f[2] }
  else if (f[1] == "block") { nb++; bo[nb] = f[2]; bc[nb] = f[3] }
  else if (f[1] == "string") {
    ns++; so[ns] = f[2]; sc[ns] = f[3]; se[ns] = f[4]
    sio[ns] = f[5]; sic[ns] = f[6]; sml[ns] = f[7]
  }
  next
}

FNR == 1 { sp = 0; push("C", 0) }

{
  line = $0; n = length(line); pos = 1; out = ""
  while (pos <= n) {
    t = st[sp]; k = sk[sp]
    if (t == "C" || t == "I") {
      rest = substr(line, pos); best = 0; btok = ""; bkind = ""; bk = 0
      for (i = 1; i <= nl; i++) consider(index(rest, lo[i]), lo[i], "L", i)
      for (i = 1; i <= nb; i++) consider(index(rest, bo[i]), bo[i], "B", i)
      for (i = 1; i <= ns; i++) consider(index(rest, so[i]), so[i], "S", i)
      if (t == "I") {
        consider(index(rest, sic[k]), sic[k], "X", k)
        if (sic[k] == "}") consider(index(rest, "{"), "{", "O", k)
      }
      if (best == 0) { out = out rest; break }
      out = out substr(rest, 1, best - 1)
      pos += best - 1
      if (bkind == "L") { emit_comment(FNR, substr(line, pos + length(btok))); out = out " "; break }
      if (bkind == "B") { push("B", bk); cbody = ""; cline = FNR; out = out " "; pos += length(btok); continue }
      if (bkind == "S") { push("S", bk); out = out btok; pos += length(btok); continue }
      if (bkind == "O") { depth[sp]++; out = out btok; pos += length(btok); continue }
      if (depth[sp] > 0) { depth[sp]--; out = out btok }
      else { sp--; out = out " " }
      pos += length(btok)
      continue
    }
    if (t == "B") {
      rest = substr(line, pos); j = index(rest, bc[k])
      if (j == 0) { cbody = cbody rest " "; break }
      cbody = cbody substr(rest, 1, j - 1)
      emit_comment(cline, cbody)
      sp--; out = out " "; pos += j - 1 + length(bc[k])
      continue
    }
    if (se[k] != "" && substr(line, pos, length(se[k])) == se[k]) { pos += length(se[k]) + 1; continue }
    if (sio[k] != "" && substr(line, pos, length(sio[k])) == sio[k]) { push("I", k); out = out " "; pos += length(sio[k]); continue }
    if (substr(line, pos, length(sc[k])) == sc[k]) { sp--; out = out sc[k]; pos += length(sc[k]); continue }
    pos++
  }
  while (sp > 1 && (st[sp] == "S" && sml[sk[sp]] != "true" || st[sp] == "I" && sml[sk[sp]] != "true")) sp--
  print FILENAME "\t" FNR "\t" out >> code_out
}
