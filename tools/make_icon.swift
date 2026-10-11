import Cocoa
let size=1024
let image=NSImage(size:NSSize(width:size,height:size))
image.lockFocus()
NSColor(calibratedRed:0.97,green:0.23,blue:0.35,alpha:1).setFill()
NSBezierPath(roundedRect:NSRect(x:0,y:0,width:size,height:size),xRadius:220,yRadius:220).fill()
NSColor.white.setFill()
NSBezierPath(roundedRect:NSRect(x:260,y:210,width:510,height:600),xRadius:65,yRadius:65).fill()
NSColor(calibratedRed:1,green:0.88,blue:0.9,alpha:1).setFill()
NSBezierPath(rect:NSRect(x:310,y:210,width:35,height:600)).fill()
let label="活" as NSString
label.draw(in:NSRect(x:390,y:370,width:340,height:340),withAttributes:[.font:NSFont.systemFont(ofSize:255,weight:.bold),.foregroundColor:NSColor(calibratedRed:0.97,green:0.23,blue:0.35,alpha:1)])
NSColor(calibratedRed:0.96,green:0.74,blue:0.78,alpha:1).setFill()
NSBezierPath(roundedRect:NSRect(x:387,y:285,width:310,height:24),xRadius:12,yRadius:12).fill()
image.unlockFocus()
let rep=NSBitmapImageRep(data:image.tiffRepresentation!)!
try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
