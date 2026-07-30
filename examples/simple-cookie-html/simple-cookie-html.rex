.response~content_type = 'text/html; charset=utf-8'

remembered = .request~cookie("name")

If .request~arg("forget", "Exists") Then Do
  gone = .HTTP.Cookie~new("name", "")
  gone~path    = "/"
  gone~max_age = 0
  .response~addcookie(gone)
  remembered = ""
End
Else If remembered = "", .request~arg("name", "Exists") Then Do
  name = .request~arg("name")
  If name \= "" Then Do
    c = .HTTP.Cookie~new("name", .response~encodeURIComponent(name))
    c~path = "/"
    .response~addcookie(c)
    remembered = name
  End
End

Say '<!DOCTYPE html>'
Say '<html lang="en">'
Say '  <head>'
Say "    <title>Setting, reading and resetting a cookie</title>"
Say '  </head>'
Say '  <body>'

If remembered \= "" Then Call Welcome
Else Call PrintForm

Say '    <p>'
Say '      <small><a href="../">⬅️ Back to the examples.</a></small>'
Say '    </p>'
Say '  </body>'
Say '</html>'
Exit

Welcome:
  Say '    <p>Welcome back, '.response~encodeHTML(remembered)'!</p>'
  Say '    <p><small><a href="?forget=1">Forget me</a></small></p>'
Return

PrintForm:
  Say '    <form method="get">'
  Say '      <label>Please enter your name: <input type="text" name="name"></label>'
  Say '      <button type="submit">Remember me</button>'
  Say '    </form>'
Return
