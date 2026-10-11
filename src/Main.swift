import Cocoa
@preconcurrency import WebKit
import PDFKit
import Vision
import SQLite3
import Security
import CryptoKit
import SwiftUI
import Translation
import AVFoundation
import Speech
import ApplicationServices
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKUIDelegate {
 var window:NSWindow!; var web:WKWebView!; let speech=AVSpeechSynthesizer(); var translationWindow:NSWindow?; var database:OpaquePointer?
 let support=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("Youhuo Dictionary")
 var audioEngine=AVAudioEngine(); var recognitionTask:SFSpeechRecognitionTask?; var recognitionRequest:SFSpeechAudioBufferRecognitionRequest?; var audioTapped=false
 var selectionMonitor:Any?;var selectionPanel:NSPanel?;var selectionWord="";var selectionMenu:NSMenuItem?
 var stateURL:URL { support.appendingPathComponent("state.json") }
 func applicationDidFinishLaunching(_ n:Notification) {
  try? FileManager.default.createDirectory(at:support,withIntermediateDirectories:true)
  let menu=NSMenu(); let appMenu=NSMenu(); let item=NSMenuItem(); item.submenu=appMenu; menu.addItem(item); appMenu.addItem(withTitle:"关于有活词典",action:#selector(about),keyEquivalent:""); appMenu.addItem(.separator()); appMenu.addItem(withTitle:"退出有活词典",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
  let edit=NSMenu(); let editItem=NSMenuItem(title:"编辑",action:nil,keyEquivalent:""); editItem.submenu=edit; menu.addItem(editItem)
  for (name,action,key) in [("撤销","undo:","z"),("剪切","cut:","x"),("复制","copy:","c"),("粘贴","paste:","v"),("全选","selectAll:","a")] {edit.addItem(withTitle:name,action:Selector(action),keyEquivalent:key)}
  let toolsMenu=NSMenu();let toolsItem=NSMenuItem(title:"工具",action:nil,keyEquivalent:"");toolsItem.submenu=toolsMenu;menu.addItem(toolsItem);toolsMenu.addItem(withTitle:"查询剪贴板文本",action:#selector(lookupClipboard),keyEquivalent:"l");let selectionItem=NSMenuItem(title:"开启划词查询",action:#selector(toggleSelectionMenu),keyEquivalent:"");toolsMenu.addItem(selectionItem);selectionMenu=selectionItem;NSApp.mainMenu=menu;NSApp.servicesProvider=self;NSUpdateDynamicServices()
  let config=WKWebViewConfiguration(); config.userContentController.add(self,name:"native")
  let data=(try? Data(contentsOf:stateURL)) ?? Data("null".utf8)
  let encoded=data.base64EncodedString(); config.userContentController.addUserScript(WKUserScript(source:"try {window.__initialData=JSON.parse(decodeURIComponent(escape(atob('\(encoded)'))));}catch(e){window.__initialData=null}",injectionTime:.atDocumentStart,forMainFrameOnly:true))
  web=WKWebView(frame:.zero,configuration:config); web.uiDelegate=self
  window=NSWindow(contentRect:NSRect(x:0,y:0,width:1120,height:780),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false); window.title="有活词典"; window.minSize=NSSize(width:800,height:600); window.contentView=web; window.center(); window.makeKeyAndOrderFront(nil)
  if let db=Bundle.main.url(forResource:"dictionary",withExtension:"sqlite") {sqlite3_open_v2(db.path,&database,SQLITE_OPEN_READONLY,nil)}
  if let url=Bundle.main.url(forResource:"index",withExtension:"html") {web.loadFileURL(url,allowingReadAccessTo:url.deletingLastPathComponent())}
  NSApp.activate(ignoringOtherApps:true)
 }
 func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool {true}
 @objc func lookupClipboard(){if let text=NSPasteboard.general.string(forType:.string),!text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty {window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true);emit("query",["text":String(text.prefix(500))])}else{error("剪贴板没有文本")}}
 @objc func lookupSelection(_ pasteboard:NSPasteboard,userData:String?,error:AutoreleasingUnsafeMutablePointer<NSString?>){if let text=pasteboard.string(forType:.string){window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true);emit("query",["text":String(text.prefix(500))])}}
 func applicationWillTerminate(_ notification:Notification){disableSelection();stopTranscription();speech.stopSpeaking(at:.immediate);sqlite3_close(database)}
 @objc func about(){NSApp.orderFrontStandardAboutPanel(options:[.applicationName:"有活词典",.applicationVersion:"1.0",.credits:NSAttributedString(string:"独立词典应用 · 离线词库与本地学习记录")])}
 func emit(_ event:String,_ value:Any) {DispatchQueue.main.async {guard let data=try? JSONSerialization.data(withJSONObject:value,options:[.fragmentsAllowed]),let json=String(data:data,encoding:.utf8),let e=try? JSONSerialization.data(withJSONObject:event,options:[.fragmentsAllowed]),let eventJSON=String(data:e,encoding:.utf8) else{return}; self.web.evaluateJavaScript("window.receiveNative && window.receiveNative(\(eventJSON),\(json))",completionHandler:nil)}}
 func error(_ message:String,_ id:Any="") {emit("error",["id":id,"message":message])}
 func userContentController(_ u:WKUserContentController,didReceive m:WKScriptMessage) {
  guard let p=m.body as? [String:Any] else{return}; let action=p["action"] as? String ?? p["type"] as? String ?? ""; let raw=p["payload"] as? [String:Any] ?? p; let id=raw["id"] ?? ""
  switch action {
  case "toggleSelection": toggleSelection(raw["enabled"] as? Bool ?? false)
  case "lookup": lookup(raw)
  case "save": do {let obj=p["payload"] ?? p["data"] ?? raw["state"] ?? raw; let data=try JSONSerialization.data(withJSONObject:obj,options:[.sortedKeys]); if FileManager.default.fileExists(atPath:stateURL.path){try? FileManager.default.removeItem(at:support.appendingPathComponent("state.previous.json")); try? FileManager.default.copyItem(at:stateURL,to:support.appendingPathComponent("state.previous.json"))}; try data.write(to:stateURL,options:.atomic)}catch{self.error("保存失败")}
  case "speak": speech.stopSpeaking(at:.immediate); let utterance=AVSpeechUtterance(string:raw["text"] as? String ?? ""); utterance.voice=AVSpeechSynthesisVoice(language:raw["lang"] as? String ?? "en-US"); speech.speak(utterance)
  case "startTranscription": startTranscription(raw)
  case "stopTranscription": stopTranscription()
  case "importTranscription": importTranscription(raw)
  case "stopSpeech": speech.stopSpeaking(at:.immediate)
  case "copy": NSPasteboard.general.clearContents(); NSPasteboard.general.setString(raw["text"] as? String ?? "",forType:.string)
  case "importDocument": importDocument()
  case "ocr": ocr()
  case "screenshot": screenshot()
  case "export": exportState(raw)
  case "import": importState()
  case "settingsNative": credentials()
  case "translate": if raw["provider"] as? String == "youdao" {translate(raw)} else {appleTranslate(raw)}
  case "ai": self.error("AI 服务尚未配置。可使用离线查词或配置有道翻译服务。",id)
  default: break
  }
 }
 @objc func toggleSelectionMenu(){toggleSelection(selectionMonitor == nil)}
 func disableSelection(){if let monitor=selectionMonitor{NSEvent.removeMonitor(monitor)};selectionMonitor=nil;selectionPanel?.orderOut(nil);selectionPanel=nil;selectionMenu?.title="开启划词查询"}
 func toggleSelection(_ enabled:Bool){
  if !enabled {disableSelection();emit("selectionState",["enabled":false]);return}
  guard AXIsProcessTrusted() else {
   let alert=NSAlert();alert.messageText="开启划词查询";alert.informativeText="读取其他应用中你选中的文字，并仅在本机离线查词。此功能需要在 macOS 系统设置的辅助功能中授权有活词典。不会读取剪贴板，也不会发送选中文字到网络。";alert.addButton(withTitle:"前往授权");alert.addButton(withTitle:"取消")
   if alert.runModal() == .alertFirstButtonReturn {let options=[kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary;_ = AXIsProcessTrustedWithOptions(options)}
   emit("selectionState",["enabled":false,"needsPermission":true]);emit("status",["message":"划词查询仍已关闭。授权后请再次点击开启。"]);return
  }
  guard selectionMonitor == nil else{return}
  selectionMonitor=NSEvent.addGlobalMonitorForEvents(matching:.leftMouseUp){_ in DispatchQueue.main.asyncAfter(deadline:.now()+0.25){self.readSelection()}}
  selectionMenu?.title="关闭划词查询";emit("selectionState",["enabled":selectionMonitor != nil]);emit("status",["message":"划词查询已开启，仅使用离线词库"])
 }
 func readSelection(){
  guard selectionMonitor != nil,NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier else{return}
  var focused:CFTypeRef?;guard AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(),kAXFocusedUIElementAttribute as CFString,&focused) == .success,let focused=focused,CFGetTypeID(focused)==AXUIElementGetTypeID() else{return}
  let element=unsafeBitCast(focused,to:AXUIElement.self);var selected:CFTypeRef?;guard AXUIElementCopyAttributeValue(element,kAXSelectedTextAttribute as CFString,&selected) == .success,let text=selected as? String else{return}
  let q=text.trimmingCharacters(in:.whitespacesAndNewlines);guard !q.isEmpty,q.count<=100,!q.contains("\n") else{selectionPanel?.orderOut(nil);return}
  selectionWord=q
  let ascii=q.unicodeScalars.allSatisfy{$0.value<128};let sql=ascii ? "SELECT phonetic,translation FROM entries WHERE word=? COLLATE NOCASE LIMIT 1" : "SELECT phonetic,translation FROM entries WHERE translation LIKE ? LIMIT 1";var stmt:OpaquePointer?;var phonetic="";var translation="离线词库未找到结果，可打开主窗口查看建议。"
  if sqlite3_prepare_v2(database,sql,-1,&stmt,nil)==SQLITE_OK{let param=ascii ? q : "%\(q)%";sqlite3_bind_text(stmt,1,param,-1,unsafeBitCast(-1,to:sqlite3_destructor_type.self));if sqlite3_step(stmt)==SQLITE_ROW{phonetic=sqlite3_column_text(stmt,0).map{String(cString:$0)} ?? "";translation=sqlite3_column_text(stmt,1).map{String(cString:$0)} ?? ""}};sqlite3_finalize(stmt)
  let panel=selectionPanel ?? NSPanel(contentRect:NSRect(x:0,y:0,width:350,height:205),styleMask:[.nonactivatingPanel,.titled,.closable],backing:.buffered,defer:false);selectionPanel=panel;panel.title="有活词典 · 划词";panel.level = .floating;panel.hidesOnDeactivate=false;panel.isReleasedWhenClosed=false
  let view=NSView(frame:NSRect(x:0,y:0,width:350,height:205));let title=NSTextField(labelWithString:q);title.font = .boldSystemFont(ofSize:18);title.frame=NSRect(x:16,y:158,width:318,height:27);view.addSubview(title);let phon=NSTextField(labelWithString:phonetic);phon.textColor = .secondaryLabelColor;phon.frame=NSRect(x:16,y:131,width:318,height:22);view.addSubview(phon);let meaning=NSTextField(wrappingLabelWithString:translation.replacingOccurrences(of:"\\n",with:"\n"));meaning.frame=NSRect(x:16,y:47,width:318,height:80);view.addSubview(meaning);let button=NSButton(title:"打开词条",target:self,action:#selector(openSelectedWord));button.frame=NSRect(x:234,y:10,width:100,height:30);view.addSubview(button);panel.contentView=view
  let cursor=NSEvent.mouseLocation;let bounds=(NSScreen.screens.first{$0.frame.contains(cursor)} ?? NSScreen.main)?.visibleFrame ?? NSRect(x:0,y:0,width:1440,height:900);panel.setFrameOrigin(NSPoint(x:min(max(cursor.x+12,bounds.minX),bounds.maxX-350),y:min(max(cursor.y-225,bounds.minY),bounds.maxY-230)));panel.orderFrontRegardless()
 }
 @objc func openSelectedWord(){selectionPanel?.orderOut(nil);window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true);emit("query",["text":selectionWord])}
 func lookup(_ p:[String:Any]) {
  let q=(p["query"] as? String ?? "").trimmingCharacters(in:.whitespacesAndNewlines); let id=p["id"] ?? ""; guard !q.isEmpty,q.count<500 else{emit("lookup",["id":id,"query":q,"entries":[],"suggestions":[]]);return}
  guard database != nil else{error("离线词库未安装",id);return}
  var entries=[[String:String]](); var stmt:OpaquePointer?
  let ascii=q.unicodeScalars.allSatisfy{$0.value<128}; let sql=ascii ? "SELECT word,phonetic,translation,definition,pos,exchange,tag FROM entries WHERE word = ? COLLATE NOCASE LIMIT 30" : "SELECT word,phonetic,translation,definition,pos,exchange,tag FROM entries WHERE translation LIKE ? LIMIT 30"
  if sqlite3_prepare_v2(database,sql,-1,&stmt,nil)==SQLITE_OK {let param=ascii ? q : "%\(q)%"; sqlite3_bind_text(stmt,1,param,-1,unsafeBitCast(-1,to:sqlite3_destructor_type.self)); while sqlite3_step(stmt)==SQLITE_ROW {var row=[String:String](); for (i,k) in ["word","phonetic","translation","definition","pos","exchange","tag"].enumerated(){row[k]=sqlite3_column_text(stmt,Int32(i)).map{String(cString:$0)} ?? ""}; entries.append(row)}}; sqlite3_finalize(stmt)
  var suggestions=[String](); stmt=nil
  if ascii,sqlite3_prepare_v2(database,"SELECT word FROM entries WHERE word LIKE ? ESCAPE '\\' ORDER BY length(word),word LIMIT 16",-1,&stmt,nil)==SQLITE_OK {let param=q.replacingOccurrences(of:"\\",with:"\\\\").replacingOccurrences(of:"%",with:"\\%").replacingOccurrences(of:"_",with:"\\_")+"%"; sqlite3_bind_text(stmt,1,param,-1,unsafeBitCast(-1,to:sqlite3_destructor_type.self)); while sqlite3_step(stmt)==SQLITE_ROW {if let v=sqlite3_column_text(stmt,0){suggestions.append(String(cString:v))}}}; sqlite3_finalize(stmt)
  emit("lookup",["id":id,"query":q,"entries":entries,"suggestions":suggestions])
 }
 func importDocument(){let panel=NSOpenPanel(); panel.allowedContentTypes=[.plainText,.pdf,UTType(filenameExtension:"md") ?? .plainText]; if panel.runModal() == .OK,let url=panel.url {do{let text:String; if url.pathExtension.lowercased()=="pdf" {guard let pdf=PDFDocument(url:url) else{error("无法读取 PDF");return}; text=pdf.string ?? ""}else{text=try String(contentsOf:url,encoding:.utf8)}; emit("document",["name":url.lastPathComponent,"text":String(text.prefix(1000000))])}catch{self.error("读取文件失败，请选择 UTF-8 文本或 PDF")}}}
 func ocr(){let panel=NSOpenPanel(); panel.allowedContentTypes=[.image]; guard panel.runModal() == .OK,let url=panel.url else{return}; DispatchQueue.global(qos:.userInitiated).async {let request=VNRecognizeTextRequest(); request.recognitionLevel = .accurate; request.recognitionLanguages=["zh-Hans","en-US"]; request.usesLanguageCorrection=true; do{try VNImageRequestHandler(url:url).perform([request]); let result=request.results?.compactMap{$0.topCandidates(1).first?.string}.joined(separator:"\n") ?? ""; self.emit("document",["text":result,"name":url.lastPathComponent])}catch{self.error("图片文字识别失败")}}}
 func screenshot(){
  let url=FileManager.default.temporaryDirectory.appendingPathComponent("youhuo-\(UUID().uuidString).png")
  window.orderOut(nil)
  DispatchQueue.global(qos:.userInitiated).async {
   let process=Process(); process.executableURL=URL(fileURLWithPath:"/usr/sbin/screencapture"); process.arguments=["-i","-x",url.path]; process.standardOutput=FileHandle.nullDevice; process.standardError=FileHandle.nullDevice
   do{try process.run();process.waitUntilExit();DispatchQueue.main.async{self.window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)};guard FileManager.default.fileExists(atPath:url.path) else{self.emit("status",["message":"截图已取消或未获得屏幕录制权限"]);return};defer{try? FileManager.default.removeItem(at:url)}
    let req=VNRecognizeTextRequest();req.recognitionLevel = .accurate;req.recognitionLanguages=["zh-Hans","en-US"];req.usesLanguageCorrection=true;try VNImageRequestHandler(url:url).perform([req]);self.emit("document",["name":"截图文字","text":req.results?.compactMap{$0.topCandidates(1).first?.string}.joined(separator:"\n") ?? ""])
   }catch{DispatchQueue.main.async{self.window.makeKeyAndOrderFront(nil)};self.error("截图识别失败，请检查 macOS 屏幕录制权限，或使用图片识别导入")}
  }
 }
 func stopTranscription(){audioEngine.stop();if audioTapped {audioEngine.inputNode.removeTap(onBus:0);audioTapped=false};recognitionRequest?.endAudio();recognitionRequest=nil;recognitionTask?.cancel();recognitionTask=nil}
 func speechPermission(_ completion:@escaping(Bool)->Void){SFSpeechRecognizer.requestAuthorization{status in DispatchQueue.main.async{completion(status == .authorized)}}}
 func recognizer(_ p:[String:Any])->SFSpeechRecognizer? {guard let rec=SFSpeechRecognizer(locale:Locale(identifier:p["lang"] as? String ?? "en-US")),rec.isAvailable,rec.supportsOnDeviceRecognition else{error("当前语言或设备不支持离线语音识别，请尝试英语或普通话并检查系统语言模型。");return nil};return rec}
 func startTranscription(_ p:[String:Any]) {
  stopTranscription();speechPermission{allowed in guard allowed else{self.error("语音识别权限未开启，可在系统设置中允许有活词典。");return};AVCaptureDevice.requestAccess(for:.audio){granted in DispatchQueue.main.async{guard granted else{self.error("麦克风权限未开启");return};guard let recognizer=self.recognizer(p) else{return};let request=SFSpeechAudioBufferRecognitionRequest();request.requiresOnDeviceRecognition=true;request.shouldReportPartialResults=true;self.recognitionRequest=request;let node=self.audioEngine.inputNode;let format=node.outputFormat(forBus:0);guard format.sampleRate>0,format.channelCount>0 else{self.error("没有可用麦克风");return};node.installTap(onBus:0,bufferSize:1024,format:format){buffer,_ in request.append(buffer)};self.audioTapped=true
   self.recognitionTask=recognizer.recognitionTask(with:request){result,error in if let result=result {self.emit("transcript",["text":result.bestTranscription.formattedString,"final":result.isFinal]);if result.isFinal{DispatchQueue.main.async{self.stopTranscription()}}};if let error=error as NSError?,error.code != 216 {self.error("本地语音识别未完成，请检查语言模型或重试。");DispatchQueue.main.async{self.stopTranscription()}}};do{self.audioEngine.prepare();try self.audioEngine.start();self.emit("status",["message":"正在本地识别，请说话；点击停止结束。"])}catch{self.stopTranscription();self.error("麦克风录音启动失败")}
  }}}
 }
 func importTranscription(_ p:[String:Any]) {speechPermission{allowed in guard allowed else{self.error("语音识别权限未开启");return};let panel=NSOpenPanel();panel.allowedContentTypes=[.audio];guard panel.runModal() == .OK,let url=panel.url,let recognizer=self.recognizer(p) else{return};self.stopTranscription();let request=SFSpeechURLRecognitionRequest(url:url);request.requiresOnDeviceRecognition=true;request.shouldReportPartialResults=true;self.recognitionTask=recognizer.recognitionTask(with:request){result,error in if let result=result {self.emit("transcript",["text":result.bestTranscription.formattedString,"final":result.isFinal]);if result.isFinal{DispatchQueue.main.async{self.recognitionTask=nil}}};if error != nil {self.error("音频文件本地识别失败，请检查格式、时长或语言模型。")}}}}
 func exportState(_ p:[String:Any]) {let panel=NSSavePanel(); panel.nameFieldStringValue="有活词典备份.json"; panel.allowedContentTypes=[.json]; if panel.runModal() == .OK,let url=panel.url {do{let data:Data; if let state=p["state"] {data=try JSONSerialization.data(withJSONObject:state)} else {data=try Data(contentsOf:stateURL)};try data.write(to:url,options:.atomic);emit("status",["message":"备份已导出"])}catch{self.error("导出失败")}}}
 func importState(){let panel=NSOpenPanel(); panel.allowedContentTypes=[.json]; if panel.runModal() == .OK,let url=panel.url {do{let data=try Data(contentsOf:url);guard data.count<20_000_000,let obj=try JSONSerialization.jsonObject(with:data) as? [String:Any] else{error("备份格式无效");return}; if FileManager.default.fileExists(atPath:stateURL.path){try? FileManager.default.copyItem(at:stateURL,to:support.appendingPathComponent("state.before-import-\(UUID().uuidString).json"))}; emit("importData",obj)}catch{self.error("备份读取失败")}}}
 func secret(_ name:String)->String? {let q:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"com.mario.youhuo",kSecAttrAccount as String:name,kSecReturnData as String:true];var result:CFTypeRef?;guard SecItemCopyMatching(q as CFDictionary,&result)==errSecSuccess,let d=result as? Data else{return nil};return String(data:d,encoding:.utf8)}
 func storeSecret(_ name:String,_ value:String){let q:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"com.mario.youhuo",kSecAttrAccount as String:name];SecItemDelete(q as CFDictionary);if !value.isEmpty{var add=q;add[kSecValueData as String]=Data(value.utf8);SecItemAdd(add as CFDictionary,nil)}}
 func credentials(){let alert=NSAlert();alert.messageText="有道翻译 API 设置";alert.informativeText="可选：输入你自己申请的应用 ID 和密钥。服务可能收费，文本将发送至有道。密钥仅保存在本机钥匙串，留空可清除。";alert.addButton(withTitle:"保存");alert.addButton(withTitle:"取消");let view=NSView(frame:NSRect(x:0,y:0,width:360,height:66));let key=NSTextField(frame:NSRect(x:0,y:36,width:360,height:24));key.placeholderString="应用 ID";key.stringValue=secret("youdao.appKey") ?? "";let sec=NSSecureTextField(frame:NSRect(x:0,y:0,width:360,height:24));sec.placeholderString="应用密钥";sec.stringValue=secret("youdao.secret") ?? "";view.addSubview(key);view.addSubview(sec);alert.accessoryView=view;if alert.runModal() == .alertFirstButtonReturn{storeSecret("youdao.appKey",key.stringValue);storeSecret("youdao.secret",sec.stringValue);emit("status",["message":"翻译服务设置已保存。默认使用免费的 macOS 本地翻译。"] )}}
 func appleTranslate(_ p:[String:Any]) {
  let id=p["id"] ?? ""; let text=p["text"] as? String ?? ""; guard !text.isEmpty,text.count<=10000 else{error("请输入不超过 10000 字的文本",id);return}
  if #available(macOS 15.0, *) {
   guard translationWindow == nil else{error("请先完成或取消当前翻译",id);return}
   func language(_ value:String)->Locale.Language? {if value == "auto" {return nil};return Locale.Language(identifier:value == "zh-CHS" ? "zh-Hans" : value == "zh-CHT" ? "zh-Hant" : value)}
   let config=TranslationSession.Configuration(source:language(p["from"] as? String ?? "auto"),target:language(p["to"] as? String ?? "zh-Hans"))
   let sheet=NSWindow(contentRect:NSRect(x:0,y:0,width:430,height:170),styleMask:[.titled],backing:.buffered,defer:false); sheet.title="本地翻译"; translationWindow=sheet
   sheet.contentView=NSHostingView(rootView:LocalTranslationView(configuration:config,text:text,complete:{result in
    self.window.endSheet(sheet); sheet.orderOut(nil); self.translationWindow=nil
    switch result {case .success(let value):self.emit("translation",["id":id,"text":value,"translation":value]);case .failure(_):self.error("本地翻译未完成。请检查语言是否受支持、系统语言模型下载和网络连接。",id)}
   }))
   window.beginSheet(sheet)
  } else {error("本地翻译需要 macOS 15 或更新版本。可在设置配置有道翻译 API。",id)}
 }
 func translate(_ p:[String:Any]) {let id=p["id"] ?? "";let text=p["text"] as? String ?? "";guard let key=secret("youdao.appKey"),let sec=secret("youdao.secret"),!key.isEmpty,!sec.isEmpty else{error("在线翻译尚未配置。请在设置中输入自己的有道 API 应用 ID 和密钥。离线查词可直接使用。",id);return};guard !text.isEmpty,text.count<=10000 else{error("请输入不超过 10000 字的文本",id);return};let salt=UUID().uuidString;let time=String(Int(Date().timeIntervalSince1970));let chars=Array(text);let input=chars.count<=20 ? text : String(chars.prefix(10))+String(chars.count)+String(chars.suffix(10));let sign=SHA256.hash(data:Data((key+input+salt+time+sec).utf8)).map{String(format:"%02x",$0)}.joined();var components=URLComponents();components.queryItems=["q":text,"from":p["from"] as? String ?? "auto","to":p["to"] as? String ?? "zh-CHS","appKey":key,"salt":salt,"sign":sign,"signType":"v3","curtime":time].map{URLQueryItem(name:$0.key,value:$0.value)};var request=URLRequest(url:URL(string:"https://openapi.youdao.com/api")!);request.httpMethod="POST";request.timeoutInterval=25;request.setValue("application/x-www-form-urlencoded",forHTTPHeaderField:"Content-Type");request.httpBody=components.percentEncodedQuery?.replacingOccurrences(of:"+",with:"%2B").data(using:.utf8);URLSession.shared.dataTask(with:request){data,response,err in guard err==nil,let data=data,let obj=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else{self.error("翻译服务连接失败或超时",id);return};guard obj["errorCode"] as? String == "0",let results=obj["translation"] as? [String] else{self.error("翻译服务返回错误：\(obj["errorCode"] as? String ?? "未知")",id);return};self.emit("translation",["id":id,"text":results.joined(separator:"\n"),"translation":results.joined(separator:"\n")])}.resume()}
 func webView(_ webView:WKWebView,runJavaScriptAlertPanelWithMessage message:String,initiatedByFrame frame:WKFrameInfo,completionHandler:@escaping()->Void){let alert=NSAlert();alert.messageText=message;alert.runModal();completionHandler()}
 func webView(_ webView:WKWebView,runJavaScriptTextInputPanelWithPrompt prompt:String,defaultText:String?,initiatedByFrame frame:WKFrameInfo,completionHandler:@escaping(String?)->Void){let alert=NSAlert();alert.messageText=prompt;alert.addButton(withTitle:"确定");alert.addButton(withTitle:"取消");let field=NSTextField(frame:NSRect(x:0,y:0,width:350,height:26));field.stringValue=defaultText ?? "";alert.accessoryView=field;alert.window.initialFirstResponder=field;completionHandler(alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil)}
 func webView(_ webView:WKWebView,runJavaScriptConfirmPanelWithMessage message:String,initiatedByFrame frame:WKFrameInfo,completionHandler:@escaping(Bool)->Void){let alert=NSAlert();alert.messageText=message;alert.addButton(withTitle:"确定");alert.addButton(withTitle:"取消");completionHandler(alert.runModal() == .alertFirstButtonReturn)}
}
@available(macOS 15.0, *)
struct LocalTranslationView: View {
 let configuration:TranslationSession.Configuration; let text:String; let complete:(Result<String,Error>)->Void
 @State private var finished=false
 var body:some View {
  VStack(spacing:16){Text("正在使用 macOS 本地翻译").font(.headline);Text("首次使用可能需要下载语言模型，请按系统提示完成。\n语言模型安装后可离线翻译。").multilineTextAlignment(.center);Button("取消"){finish(.failure(CancellationError()))}}.padding(24).frame(width:430,height:170)
  .translationTask(configuration){session in do{try await session.prepareTranslation();let response=try await session.translate(text); await MainActor.run{finish(.success(response.targetText))}}catch{await MainActor.run{finish(.failure(error))}}}
 }
 func finish(_ result:Result<String,Error>){if !finished {finished=true;complete(result)}}
}
let app=NSApplication.shared;let delegate=AppDelegate();app.delegate=delegate;app.setActivationPolicy(.regular);app.run()
