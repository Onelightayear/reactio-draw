' Reactio Draw tab in Word: the template's own document module. It listens to Word, so that a double-click on a Reactio
' Draw picture opens it in Reactio Draw (as Edit drawing does) instead of Word's picture settings. Other pictures and
' Reactio Draw objects on Windows keep what Word does with them. The tab starts listening when Word loads it (RD_Load).
' Reactio Draw (c) 2026 Pavel Sakharov. Free software under the GNU Affero General Public License v3.0 or later.
Option Explicit

Public WithEvents RDApp As Word.Application

Public Sub RDListen()
    Set RDApp = Word.Application
End Sub

Private Sub RDApp_WindowBeforeDoubleClick(ByVal Sel As Selection, Cancel As Boolean)
    If ReactioDraw.RD_DoubleClick(Sel) Then Cancel = True
End Sub
