.response~content_type = 'text/html; charset=utf-8'

Say '<!DOCTYPE html>'
Say '<html lang="en">'
Say '  <head>'
Say "    <title>Reading a HTML GET form</title>"
Say '  </head>'
Say '  <body>'

If .request~arg("name", "Exists") Then Do
  name = .request~arg("name")
  If name = "" Then Say '    <p>The name can not be empty.</p>'
  Else Call Greet
End

Call PrintForm

Say '    <p>'
Say '      <small><a href="../">⬅️ Back to the examples.</a></small>'
Say '    </p>'
Say '  </body>'
Say '</html>'
Exit

Greet:
  Say '    <p>Hello, '.response~encodeHTML(name)'!</p>'
Return

PrintForm:
  Say '    <form method="get">'
  Say '      <label>Please enter your name: <input type="text" name="name"></label>'
  Say '      <button type="submit">Say hello</button>'
  Say '    </form>'
Return