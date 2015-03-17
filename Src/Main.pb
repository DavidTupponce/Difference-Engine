; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
; 'Difference Engine' patch generator v0.35
; Developed in 2010 by Guevara-chan
; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

; TODO[
; �������� ����������� ���������� ��������� ������.
; �������� ����������� ���������� ���������� �����������.
; �������� ��������� ������������� ������ ��� ��������.
; �������� ����������� ������� ������� ������� ������.
; �������� ������ �� ���������� ������������� �����.
; �������� ���������.
; ]TODO

IncludeFile "DiffGUI.pb"
EnableExplicit
Import "" ; Kernel32.lib
AttachConsole(dwProcessId)
EndImport

;{ Definitions
; --Enumerations--
Enumeration ; Files
#fVoid
#fEtalone
#fPatched
#fOutput
#fIcon
EndEnumeration

; --Constants--
#FieldsCount = 8-1 ; ���������� �����.
#EXEFiles    = "EXEcutable files (*.exe)|*.exe"
#ICOFiles    = "Icon files (*.ico)|*.ico"
#ExtraTypes  = "|Dynamic-link libraries (*.dll)|*.dll|Screen savers (*.scr)|*.scr"
#AllFiles    = "|All files (*.*)|*.*"
#FullPattern = #EXEFiles + #ExtraTypes + #AllFiles
#EXEPattern  = #EXEFiles + #AllFiles
#ICOPattern  = #ICOFiles + #AllFiles
#RedLetters   = #FOREGROUND_RED|#FOREGROUND_INTENSITY
#GreenLetters = #FOREGROUND_GREEN|#FOREGROUND_INTENSITY
#GrayLetters  = #FOREGROUND_RED|#FOREGROUND_GREEN|#FOREGROUND_BLUE

; --Structures--
Structure EventData
Type.i
SubType.i
Gadget.i
EndStructure

Structure LayerBase ; System support.
bWidth.a
bHeight.a
bColorCount.a
bReserved.a
wPlanes.u
wBitCount.u
dwBytesInRes.l
EndStructure

Structure IconLayer  Extends LayerBase
dwBytesOffset.l
EndStructure

Structure GroupLayer Extends LayerBase
nID.u
EndStructure

Structure HeaderBase ; System support.
idReserved.u         ; Reserved (must be 0)  
idType.u             ; Resource Type (1 for icons)  
idCount.u            ; How many images?  
EndStructure

Structure IcoHeader Extends HeaderBase
idEntries.IconLayer[0] ; An entry for each image.
EndStructure

Structure GroupHeader Extends HeaderBase
idEntries.GroupLayer[0] ; An entry for each image.
EndStructure

; --Varibales--
Global PatternPos.i
Global GUIEvent.EventData
Global *Out ; ��������� ��������� ������.
Global.i FIndex, GenTrigger, BreakFlag, ExitCode
Global Dim Fields.Point(#FieldsCount) ; ������ �����.
;} EndDefinitions

;{ Procedures
;{ --GUI management--
Procedure ReceiveEvent(*Container.EventData)
With *Container
\Type = WaitWindowEvent()
\SubType = EventType()
If \Type = #PB_Event_Gadget
\Gadget = EventGadget()
Else : \Gadget = #Null
EndIf
EndWith
EndProcedure

Procedure FieldFiller(*FieldID, Target.s, Pattern.s, PPos, Saving = #False)
If Saving : Define FName.s
FName = SaveFileRequester("Select location for " + Target + " file:",GetGadgetText(*FieldID), Pattern, PPos)
If FName And LCase(GetExtensionPart(FName)) <> "exe" And SelectedFilePattern() = 0 : FName + ".exe" : EndIf
Else : FName = OpenFileRequester("Locate "+Target+" file:",GetGadgetText(*FieldID), Pattern, PPos)
If PPos <> - 1 : PatternPos = SelectedFilePattern() : EndIf ; ��������� ��������� ������.
EndIf : If FName : SetGadgetText(*FieldID, FName) : EndIf
EndProcedure

Macro ShowAbout() ; Pseudo-procedure.
#ProgramSig = "'Difference Engine' patch generator v0.35"
#AuthorSig  = "Developed in 2010 by Chrono Syndrome"
MessageRequester("About me:", #ProgramSig + #CR$ + #AuthorSig, #MB_ICONINFORMATION)
EndMacro

Procedure.s LocateTarget()
Define Etalone.s = GetGadgetText(#EtaloneFile)
If Etalone ; ���� ���� ������� ��� �����-�������...
ProcedureReturn GetFilePart(Etalone)
Else : ProcedureReturn "...[No file selected]..."
EndIf
EndProcedure

Macro PutChar(InPtr, OutPtr) ; Partializer.
OutPtr\C = InPtr\C : OutPtr + SizeOf(Character)
EndMacro

Procedure.s RefineReg(Text.s)
Define *Char.Character = @Text, *COut.Character = @Text, Slash.i 
With *Char
While \C ; ���� �� ����� ������.
Select \C ; ����������� ������.
Case '\' ; ���� ��� �����������...
If Slash = #False : PutChar(*Char, *COut) : Slash = #True : EndIf
Default : PutChar(*Char, *COut) : Slash = #False ; �������� ������.
EndSelect : *Char + SizeOf(Character)
Wend : *COut\C = 0 : ProcedureReturn Text
EndWith
EndProcedure

Procedure.s ValidateField(FieldID, Text.s)
If Text = "" ; ���� ���� ������������ ������...
Select FieldID ; ����������� ������.
Case #TitleField  : ProcedureReturn "=[Generic patcher]="
Case #TargetField : ProcedureReturn LocateTarget()
; ...
EndSelect
EndIf
ProcedureReturn Text ; ����������� ���������.
EndProcedure

Macro ValidateTarget() ; Partializer.
SetGadgetText(#TargetField, LocateTarget())
EndMacro

Macro NormalizeField(FieldID) ; Pseudo-procedure.
If GUIEvent\SubType = #PB_EventType_Change ; ��������� ���� �� ���������.
Define SStart, SEnd, Gadget = GUIEvent\Gadget
Define Text.s = RTrim(GetGadgetText(Gadget))
If Text ; ���� � ���� ���� �����-�� �����...
SendMessage_(GadgetID(Gadget), #EM_GETSEL, @SStart, @SEnd)
Define TabLen = Len(Text) : Text = LTrim(Text)
If FieldID = #RegistryField : Text = RefineReg(Text) : EndIf
TabLen - Len(Text) ; ����������� ������ ��������� ��������.
If SStart <= TabLen : SEnd - SStart ; ������������ ����� ���������.
SStart = 0 ; ������������ ������ ���������.
EndIf
SetGadgetText(Gadget, Text) ; ���������� ����� ��������.
SendMessage_(GadgetID(Gadget), #EM_SETSEL, SStart, SEnd)
Else : SetGadgetText(Gadget, ValidateField(Gadget, Text)) ; ���������� ����������.
EndIf
EndIf
EndMacro

Procedure MessageOut(Title.s, Text.s, Flags = #False, Color = #GrayLetters)
Define Dummy ; ���-�� ��������� ����.
If GenTrigger <> 'Mute' ; ���� �� ������� "�����" �����...
MessageRequester(Title, Text, Flags)
Else : Text = Title + " " + Text + #CRLF$ ; �����������.
SetConsoleTextAttribute_(*Out, Color) ; ���������� ����.
WriteFile_(*Out, @Text, StringByteLength(Text), @Dummy, 0)
EndIf
EndProcedure
;}
;{ --Patching process--
Macro ShowError(ErrorMsg) ; Pseudo-procedure.
ExitCode = -1 : MessageOut("Critical error:", ErrorMsg, #MB_ICONERROR, #RedLetters)
EndMacro

Procedure IsValidIcon(*FileID, FileName.s)
If ReadLong(*FileID) = $10000 ; ���� ��������� �������...
If Lof(*FileID) >= SizeOf(IcoHeader) + ReadUnicodeCharacter(*FileID) * SizeOf(IconLayer)
CloseFile(*FileID) ; ��������� ���� ��� �����.
If LoadImage(0, FileName) ; ���� ������� ��������� ������...
FreeImage(0) : ReadFile(*FileID, FileName) ; ���������� ��� �������
ProcedureReturn #True ; ��������� �����.
EndIf
EndIf
EndIf
EndProcedure

Procedure UseFile(FName.s, *FileID, Target.s, Mode = 'None')
Define Result
If FName ; ���� ������ ���� � �����.
If *FileID = #Null ; ����������� �������
If CopyFile("Resources\Template.app", FName) : ProcedureReturn #True
Else : ShowError("Unable to create '" + GetFilePart(FName) + "' !")
EndIf
Else ; �������� ����� �� ������.
If FileSize(FName) ; ���� ���� �� ������...
If ReadFile(*FileID, FName)
If Mode = 'Icon' : If IsValidIcon(*FileId, FName) ; �������� ������...
ProcedureReturn #True ; ��������� �� �������� ��������.
Else : ShowError("Invalid icon file '" + GetFilePart(FName) + "' !")
EndIf
Else : ProcedureReturn #True ; ��������� �����.
EndIf 
Else : ShowError("Unable to open '" + GetFilePart(FName) + "' !")
EndIf
Else : ShowError("Unable to accept empty " + Target + " file !")
EndIf
EndIf
; ����� ��������� � ������ ����.
ElseIf Mode = 'None' : ShowError("Path to " + Target + " file not specified !")
EndIf
EndProcedure

Procedure AppendString(Text.s)
Define Temp.s = Text     ; Accumulator.
WriteInteger(#fOutput, StringByteLength(Text))
CharToOem_(@Temp, @Text) ; Conversion.
WriteString(#fOutput, Text)
EndProcedure

Procedure.s TempFileName(TmpDir.S, Prefix.s, Postfix.s = ".tmp")
Repeat : Define I, FileName.s = TmpDir + "\" + Prefix
For I = 1 To 5 : FileName + Chr(Random('z' - 'a') + 'a')
Next I : FileName + Postfix
Until FileSize(FileName) = -1
ProcedureReturn FileName
EndProcedure

Macro NewStream(Offset = 1) ; Partializer
WriteInteger(#fOutput, Loc(#fEtalone) - Offset) ; ���������� ��������.
Position\X = Loc(#fOutput) ; ���������� ����� ������.
WriteInteger(#fOutput, 0) ; ����������� ����� ��� �����.
EndMacro

Macro FinishStream() ; Partializer
Position\Y = Stream : Stream = 0 ; ���������� ������ ������.
AddElement(Streams()) ; ��������� ����� ������� � ������.
Streams() = Position ; ���������� ������ � ������.
EndMacro

Procedure FindDifferences()
Define Stream, Position.Point
NewList Streams.Point()
While Not Eof(#fEtalone)
Define Byte.b = ReadByte(#fPatched)
If ReadByte(#fEtalone) = Byte ; ���� ����� ���������...
If Stream : FinishStream() : EndIf ; ���� ������ ������� ����� �������� - �������.
ElseIf Stream = 0 : Stream = 1 : NewStream() ; ���� ����� ��������...
WriteByte(#fOutput, Byte) ; ���������� ������ ���� ��������.
Else : WriteByte(#fOutput, Byte) ; ���������� ���� ��������.
Stream + 1 ; �������������� �������.
EndIf
Wend
; ��������� �� ������ �����:
If Not Eof(#fPatched) ; E��� �� ��� �������...
If Stream = 0 : NewStream(0) : EndIf ; �������� �������� ������.
While Not Eof(#fPatched) : WriteByte(#fOutput, ReadByte(#fPatched)) : Stream + 1 : Wend
EndIf : If Stream : FinishStream() : EndIf
; ���������� ������.
ForEach Streams() : Position = Streams()
FileSeek(#fOutput, Position\X)
WriteInteger(#fOutput, Position\Y)
Next ; ���������� ���������� �������.
ProcedureReturn ListSize(Streams())
EndProcedure

Macro InfuseIcon(IconFile, Updater) ; Pseudo-procedure.
Define IconSize = Lof(IconFile) ; ������ ������ ������.
Define *IconHeader.IcoHeader = AllocateMemory(IconSize) ; �������� ������.
ReadData(IconFile, *IconHeader, IconSize) ; ������ ������ ���������.
Define *GroupData.GroupHeader = *IconHeader ; �������� ������ ��� ������.
Define I, ToFix = *IconHeader\idCount - 1 ; ������� ����.
For I = 0 To ToFix ; ����������� ����.
Define *Layer.IconLayer = *IconHeader\idEntries[I] ; �������� ������ ����.
UpdateResource_(Updater, #RT_ICON, I, 1033, *IconHeader + *Layer\dwBytesOffset, *Layer\dwBytesInRes)
Define *GroupEntry.GroupLayer = *GroupData\idEntries[I] ; �������� ������ ������.
MoveMemory(*Layer, *GroupEntry, SizeOf(LayerBase)) ; �������� �������� ������ ����.
*GroupEntry\nID = I ; ������ �������������.
Next I
UpdateResource_(Updater,#RT_GROUP_ICON,1,1033,*GroupData,SizeOf(GroupHeader)+*IconHeader\idCount*SizeOf(GroupLayer))
FreeMemory(*IconHeader) ; ������������ ������
EndMacro

Procedure IsValidTarget(Target.s)
If FindString(Target, "|", 1) ; ���� ������ �����������...
ShowError("Compound patterns couldn't be used for targetting (yes) !")
Else : ProcedureReturn #True
EndIf
EndProcedure

Procedure GeneratePatcher()
; ���������� ���������� �����.
Define TempFile.s = Space(#MAX_PATH)
GetTempPath_(#MAX_PATH, @TempFile)
TempFile = TempFileName(TempFile, "Temporary data (", ").dat")
Define Result = #False
; Fields reading.
Define Etalone.s = GetGadgetText(#EtaloneFile)
Define Patched.s = GetGadgetText(#PatchedFile)
If CompareMemoryString(@Etalone, @Patched, #PB_String_NoCase) ; ���� ������ ������ �����...
Define Output.s  = GetGadgetText(#OutputFile)
Define Icon.s    = GetGadgetText(#IconFile)
; �������� ������.
If UseFile(Etalone, #fEtalone, "etalone")
If UseFile(Patched, #fPatched, "patched")
If UseFile(Icon   , #fIcon,    "icon", 'Icon')
If UseFile(Output,  #fVoid,    "output")
Define Target.s = GetGadgetText(#TargetField)
If IsValidTarget(Target.s) ; �������� ������� ������ �� ����������.
; ���������� ��������.
Define CRC32 = CRC32FileFingerprint(Etalone)
If CRC32FileFingerprint(Patched) <> CRC32 ; ���� ����� ������...
Define FSize = Lof(#fEtalone)
If FSize <= Lof(#fPatched) ; ���� ���� �� ���� ������ ����� �����...
If CreateFile(#fOutput, TempFile) ; �������� ������...
; ���������� ���������.
AppendString(GetGadgetText(#InfoField))  ; ���������� ���������� �������.
AppendString(Target)                     ; ���������� ������ � ������.
AppendString(GetGadgetText(#TitleField)) ; ���������� �������� �������.
AppendString(GetGadgetText(#RegistryField)) ; ���������� ���� �� ��������� ����.
WriteInteger(#fOutput, CRC32)      ; ���������� CRC ������������ �����.
WriteInteger(#fOutput, FSize)      ; ���������� ������ ������������ �����.
Result = FindDifferences() ; ���������� ������ � �������� �����.
If Result ; ���� �������� �������...
CloseFile(#fOutput) ; ��������� ���� ��������� ������.
ReadFile(#fOutput, TempFile) ; ��������� ��������� ���� �� ������.
FSize = Lof(#fOutput) ; �������� ������ ���������� �����.
Define *TempData = AllocateMemory(FSize) ; �������� ������ ��� �����.
ReadData(#fOutput, *TempData, FSize) ; ������ ������ �� ���������� �����.
Define *Update = BeginUpdateResource_(Output, #True) ; ��������� �������.
UpdateResource_(*Update, #RT_RCDATA, @"PATCH_DATA", 0, *TempData, FSize)
If IsFile(#fIcon) : InfuseIcon(#fIcon, *Update) : EndIf ; ���� ���� ������ ���� ������...
EndUpdateResource_(*Update, #False) ; ����������� ����������.
MessageOut("Work complete:","Patcher ('"+GetFilePart(Output)+"') successfully created !",#MB_ICONWARNING,#GreenLetters)
Else : ShowError("No differnce found between choosen files !") ; �������� �� �������.
EndIf
CloseFile(#fOutput)  ; ������� ��������� ����.
DeleteFile(TempFile) ; ������� ��������� ����.
Else : ShowError("No temporary storage present !")
EndIf
Else : ShowError("Patched file can't be smaller zen original one !")
EndIf
Else : ShowError("Patched file should have different CRC zen original one !")
EndIf ; �a������� � ������� ����, ���� ���-�� ����� �� ���...
If Result = #False : DeleteFile(Output) : EndIf ; ������� ������ � ������ ������.
EndIf
EndIf : DisableDebugger : CloseFile(#fIcon) : EnableDebugger ; ��������� ���� ������.
EndIf : CloseFile(#fPatched) ; ��������� ����������� ����.
EndIf : CloseFile(#fEtalone) ; ��������� ���� �������.
EndIf
Else : ShowError("Stupid user encountered !")
EndIf
EndProcedure
;}
;{ --Parsing management--
Macro ShiftPtr() ; Partializer.
*Text\I + SizeOf(Character) ; ������� ������������ ���������.
EndMacro

Procedure ParsingError(Text.s)
MessageRequester("CLI error:", Text + #CR$ + "Parsing aborted !", #MB_ICONERROR)
BreakFlag = #True ; ���������� ���� ������.
GenTrigger = 0 ; ������� �������.
EndProcedure

Macro NormalizeWord(Word) ; Pseudo-procedure.
ReplaceString(Word, #CRLF$, "`n")
EndMacro

Procedure.s ExtractWord(*Text.Integer)
Define Special.i, Word.S, Block.c, *Char.Character = *Text\I
With *Char
While \C ; ���� �� ������� ��������� ������...
If Special ; ���� ������� ����. �����...
Select \C ; A���������� ������ ��� �����������.
Case 'n', 'N' : Word + #CRLF$ ; ��������� ������� ������.
Default : Word + Chr(\C) ; ������ �������� ���� ������.
EndSelect : Special = #False ; ������� ����.
Else ; ������� ����������.
Select \C ; ����������� ������
Case ' ', #TAB ; ����������� ������.
If Block.c = 0 ; ���� �� �������� ����...
If Word : ShiftPtr() : ProcedureReturn Word : EndIf ; ���������� ���������.
Else : Word + Chr(\C) ; ���������� �����������.
EndIf
Case '"', 39 ; ������ ������� �����.
Word + Chr(\C) ; ���������� ����������� ������.
If Block.c = 0 : Block.c = \C ; ������� ����.
Else : ShiftPtr() : ProcedureReturn Word ; ���������� �����.
EndIf
Case '`' : Special = #True ; ������ ����������� ������.
Case Block ; ������� ��������� �����.
ProcedureReturn Word ; ���������� ���������.
Default : Word + Chr(\C) ; ������ ���������� ������.
EndSelect
EndIf
*Char + SizeOf(Character) : ShiftPtr() ; �������� �������.
Wend
EndWith
If Block : ParsingError("Unfinished (d)quote block encountered.")
ElseIf Special : ParsingError("Command-line couldn't end with '`'")
Else : ProcedureReturn Word ; ���������� ��� �����������.
EndIf
EndProcedure

Procedure.s ExtractPrefix(Text.s)
Define CutPos = FindString(Text, ":=", 1)
If CutPos : ProcedureReturn Left(Text, CutPos) : EndIf
EndProcedure

Procedure.s CutPrefix(Text.s)
Define CutPos = FindString(Text, ":=", 1)
If CutPos : ProcedureReturn Right(Text, Len(Text) - CutPos - 1) : EndIf
EndProcedure

Procedure.s RemoveQuotes(Text.s)
Define Start = 1, Finish = Len(Text), *Char.Character = @Text
If *Char\C = '"' Or *Char\C = 39 : Start + 1 : EndIf
*Char + StringByteLength(Text) - SizeOf(Character)
If *Char\C = '"' Or *Char\C = 39 : Finish - Start : EndIf
ProcedureReturn Mid(Text, Start, Finish)
EndProcedure

Macro RegField(FieldID) ; Pseudo-procedure.
Fields(FIndex)\Y = FieldID : FIndex + 1
EndMacro

Macro RegisterFields(Arr) ; Pseudo-procedure.
RegField(#EtaloneFile) : RegField(#PatchedFile) : RegField(#OutputFile)
RegField(#TitleField)  : RegField(#IconFile)    : RegField(#TargetField)
RegField(#RegistryField) : RegField(#InfoField)
FIndex = 0 ; �������� ����������.
EndMacro

Procedure SetField(Index, Text.s, Trim = #True, Loop = #False)
If Trim : Text = ReplaceString(Trim(Text), #CRLF$, "") : EndIf ; ��������.
Retry: ; ...� ��, ��� �����.
If Fields(Index)\X = #False ; ���� ���� ��� �� ����������...
Define FieldID = Fields(Index)\Y ; �������� ������ ����.
SetGadgetText(FieldID, ValidateField(FieldID, Text)) ; ���������� ���� ��������.
Fields(Index)\X = #True ; ���������� ����.
ProcedureReturn Index + 1 ; ��������� �����.
ElseIf Loop = #False : ParsingError("Field is already set for: " + NormalizeWord(Text))
EndIf
If Loop And Index < #FieldsCount : Index + 1 : Goto Retry : EndIf ; ���� ������ �� ��������.
EndProcedure

Procedure SetTrigger(Word.s, NewVal)
If GenTrigger = '' : GenTrigger = NewVal
Else : ParsingError("Dissonant directive found: " + NormalizeWord(Word))
EndIf
EndProcedure

Macro TooMuchArgs() ; Partializer.
ParsingError("Too much arguments: " + NormalizeWord(Word))
EndMacro

Macro AnalyzeWord(Word) ; Partializer.
Select LCase(Word) ; �����������...
Case "/cli"        : SetTrigger(Word, 'DoIt')
Case "/cli:silent" : SetTrigger(Word, 'Mute')
*Out = GetStdHandle_(#STD_OUTPUT_HANDLE) : AttachConsole(-1)
Case "/now"        : SetTrigger(Word, '/now')
Default : ; ���������� ��������� ����...
Define Trim.i ; ���� �������.
If FIndex <= #FieldsCount ; ���� ��� �� ��� ���� ���������...
If Fields(FIndex)\Y = #InfoField : Trim = #False : Else : Trim = #True : EndIf
FIndex = SetField(FIndex, Word, Trim, #True) ; ���������� ���� � �������� ������.
If FIndex = 0 : TooMuchArgs() : EndIf ; ��������� �����������.
Else : TooMuchArgs() ; ����� ��������� ����������� ����������.
EndIf
EndSelect
EndMacro

Macro ParseCL() ; Pseudo-procedure.
Define Text.s = Trim(PeekS(GetCommandLine_()))
If Text ; ���� ����, ��� �������������...
RegisterFields(Fields) ; ����������� �����.
Define *Char.Character = @Text ; ���������� ����� ������� �������.
ExtractWord(@*Char) ; ����� ����������� ��� .EXE
Repeat : Define Word.s = ExtractWord(@*Char) ; ����������� ��������� �����.
If Word = "" : Break : EndIf ; �������, ���� ��������� ����� ������.
Define Prefix.s = ExtractPrefix(Word) ; ����������� �� ����� �������.
If Prefix : Word = CutPrefix(Word) : EndIf ; �������� ��� ������, ���� ����.
Word = RemoveQuotes(Word) ; ������� ������� ����� (�������\���������).
Select LCase(Prefix) ; ����������� �������.
Case ""    : AnalyzeWord(Word) ; �������� ��� - ����������� �����.
Case "/e:" : SetField(0, Word) ; ���� ������� (�������������).
Case "/p:" : SetField(1, Word) ; ��������� ���� (�������������).
Case "/o:" : SetField(2, Word) ; �������� ���� (�������������).
Case "/t:" : SetField(3, Word) ; �������� ������� (�������������).
Case "/i:" : SetField(4, Word) ; ���� ������ (�������������).
Case "/*:" : SetField(5, Word) ; ������ ������ (�������������).
Case "/r:" : SetField(6, Word) ; ��������� ���� � �������� (�������������).
Case "/a:" : SetField(7, Word, 0) ; ���. �������� (�������������).
Default : ParsingError("Invalid prefix: " + NormalizeWord(Prefix) + "=")
EndSelect
Until BreakFlag ; ������� �� ������.
EndIf
If GenTrigger ; ���� ����������� �������...
GeneratePatcher() ; ����� ��������� ���������.
If GenTrigger <> '/now' ; ���� ���� ��������...
If GenTrigger = 'Mute' : SetConsoleTextAttribute_(*Out, #GrayLetters) : EndIf
End ExitCode ; ������� �� ���������.
EndIf 
EndIf : HideWindow(#MainWindow, #False) ; ���������� ����.
EndMacro
;}
;} EndProcedures

; ==Main loop==
Define FixDir.s = GetPathPart(ProgramFilename()) ; �� ������ cmd � ���� ���������.
If FixDir <> GetTemporaryDirectory() : SetCurrentDirectory(FixDir) : EndIf
OpenWindow_MainWindow()
ParseCL() ; CLI management.
Repeat : ReceiveEvent(GUIEvent)
Select GUIEvent\Type
Case #PB_Event_Gadget 
Select GUIEvent\Gadget
; Buttons.
Case #Button_Etalone  : FieldFiller(#EtaloneFile, "unpatched",        #FullPattern, PatternPos)
ValidateTarget() ; ���������� ����� �������� ����� "Patching target".
Case #Button_Patched  : FieldFiller(#PatchedFile, "already patched",  #FullPattern, PatternPos)
Case #Button_Output   : FieldFiller(#OutputFile , "output patcher's", #EXEPattern , -1, #True)
Case #Button_Icon     : FieldFiller(#IconFile   , "icon",             #ICOPattern , -1)
Case #Button_Generate : GeneratePatcher()
Case #Button_About    : ShowAbout()
Case #Button_Quit     : End
; Fields.
Case #TargetField, #TitleField, #EtaloneFile, #PatchedFile, #OutputFile, #IconFile, #RegistryField
NormalizeField(GUIEvent\Gadget) ; �������� ����.
If GUIEvent\Gadget = #EtaloneFile : ValidateTarget() : EndIf ; ������������ ����� "Patching target".
EndSelect
Case #PB_Event_CloseWindow : End
EndSelect
ForEver
; IDE Options = PureBasic 5.22 LTS (Windows - x86)
; Folding = 74f--
; UseIcon = ..\Resources\gear-icon.ico
; Executable = ..\Difference Engine.exe
; CurrentDirectory = ..\