/*
osc console
//tb/121028//131114 github

to test osc apis and create communication model prototypes
send/receive osc messages
hook up actions to incoming messages
javascript environment for easy osc server scripting
run native commands
control osc console from external processes
log communication to file

uses controlP5 and oscP5 libraries
http://www.sojamo.de/libraries/controlP5
http://www.sojamo.de/libraries/oscP5

in generated start script after export, add $@ at end to pass params to applet
for maxosx, add $JAVAROOT to classpath in plist file

known issues
-alt gr provoces exception. don't press it :)
-THIS PROGRAM CAN BE A SECURITY RISK IF NOT PROPERLY CONFIGURED AND USED
-KNOW WHAT YOU ARE DOING AND SECURE YOUR NETWORK TO AVOID MALICIOUS USE
*/

import controlP5.*;
import oscP5.*;
import netP5.*;

import javax.script.*;

import java.util.Vector;
import java.net.ServerSocket;
import java.net.DatagramSocket;
import java.util.regex.Pattern;
import java.util.regex.Matcher;

ControlP5 cp5;
OscP5 oscP5;
OscProperties properties;

String sVersion="0.71";

int osc_server_port=10001;
String send_to_host="127.0.0.1";
String send_to_port="10001";

int console_height=250;
int other_height=100;
int w=750;
int h=console_height+other_height;

ControlFont cf1;

Textarea txt1;
Println console;

int txt_max_lines=1000;
int txt_lines_count=0;

Textlabel l1;
Textfield t1, t2, t3;

float oldWidth;
float oldHeight;

TrashCollector ts;

//osc processing
boolean is_enabled=true;
boolean is_paused=false;

//suppress anything that would print to console
//due to the nature of the console, a lot of message will
//make it very slow. "cl" will clear it
//for known traffic intensive things printing can be turned off
boolean is_print_enabled=true;

boolean is_log_enabled=false;
boolean is_log_append=true;

String sLogFilename="";
String sLogDir="";
PrintWriter pwriter;

String os;
boolean isUnix;
boolean isWindows;
boolean isMac;

//String sLineEnd="\n";
String sLineEnd=System.getProperty("line.separator");
String sPathSeparator=System.getProperty("file.separator");

String sFontName="";
int fontSize=14;

String config="data"+sPathSeparator+"oscc_actions.csv";
String[] prefs;

Vector<OSCAction> vActions=new Vector<OSCAction>();
RunCmd cmd;

OSCRegexMatcher regex;

//Vector vMessageStore;
HashMap<String, OscMessage> messageStore = new HashMap<String, OscMessage>();

ScriptEngine js;
ScriptEngineManager js_factory;
String sJsUri="data"+sPathSeparator+"oscc_scripts.js";

public OSCC_API oscc_api=new OSCC_API();

Poller poller;

/*
//test
 boolean sketchFullScreen()
 {
 return true;
 }
 */

// ===========================================================================
void setup() 
{
  os = System.getProperty("os.name").toLowerCase();
  isUnix = os.indexOf("nix") >= 0 || os.indexOf("nux") >= 0;
  isWindows = os.indexOf("win") >= 0;
  isMac = os.indexOf("mac") >= 0;

  if (isMac)
  {
    sLogDir=System.getProperty("user.home")+"/Library/Application Support/OSC_CONTROL/";
    File f=new File(sLogDir);
    if (!f.exists())
    {
      f.mkdir();
    }
  }
  else
  {
    sLogDir=System.getProperty("java.io.tmpdir")+sPathSeparator;
  }

  //read from command line args
  try
  {
    if (args.length>=1)
    {

      if (args[0].equals("help") || args[0].equals("--help"))
      {
        showHelp();
        showAbout();
        exit2();
      }
      
      //processing 2.1 calls with --sketch-path param on 'play'
      if(args[0].startsWith("--sketch-path"))
      {
         //ignore
      }
      else
      {
        osc_server_port=Integer.parseInt(args[0]); 
      }
    }
    if (args.length>=3)
    {
      send_to_host=args[1];
      send_to_port=args[2];
    }
    if (args.length>=4)
    {
      sFontName=args[3];
      if(args.length>=5)
      {
        fontSize=Integer.parseInt(args[4]);
      }
    }
  }
  catch(Exception e)
  {
    println("error: "+e.getMessage());
    exit2();
  }

  //this has to be done before starting osc server
  //oscP5 does not throw up exceptions to recognize
  if (!checkIfPortAvail(osc_server_port))
  {
    osc_server_port=10001;
    while (osc_server_port<=10100 && !checkIfPortAvail (osc_server_port))
    {
      //keep on seeking next free port
      osc_server_port++;
    }
    //final check
    if (!checkIfPortAvail(osc_server_port))
    {
      exit();
    }
    //send_to_port=String.valueOf(osc_server_port);
  }

  createGlobalGui();

  properties = new OscProperties();
  //  properties.setRemoteAddress(send_to_host, Integer.parseInt(send_to_port));
  properties.setListeningPort(osc_server_port);

  /* Send Receive Same Port is an option where the sending and receiving port are the same.
   * this is sometimes necessary for example when sending osc packets to supercolider server.
   * while both port numbers are the same, the receiver can simply send an osc packet back to
   * the host and port the message came from.
   */
  properties.setSRSP(OscProperties.ON);
  /* set the datagram byte buffer size. this can be useful when you send/receive
   * huge amounts of data, but keep in mind, that UDP is limited to 64k
   */
  properties.setDatagramSize(1024);

  //start osc server now
  oscP5 = new OscP5(this, properties);    

  ts=new TrashCollector(1111);
  ts.start();

  console.clear();

  js_factory=new ScriptEngineManager();

  p_("LDJ: loading JavaScript from: "+sJsUri);
  loadScripts();

  cmd=new RunCmd();
  regex=new OSCRegexMatcher();

  p_("LDA: loading actions config from: "+config);
  parseConfig(config);

  //call startup hook (method must exist in oscc_scripts.js)
  js_eval("startupHook()");

  p_("INF: welcome to OSC console v"+sVersion);
  p_("INF: ready. enter 'help' for more");

  frameRate(10);
}

//load / reload (all status is lost on reload)
void loadScripts()
{
  js=js_factory.getEngineByName("JavaScript");

  if (js==null)
  {
    p_("ERR: error loading scripts: "+sJsUri);
    return;
  }

  try 
  {
    Bindings js_bindings=js.createBindings();
    //js_bindings.put("oscc", this);
    js_bindings.put("oscc", oscc_api);
    js.setBindings(js_bindings, ScriptContext.ENGINE_SCOPE);

    js_eval(getAsString(sJsUri));
  }
  catch(Exception e)
  {
    println("error loading js: "+e.getMessage());
  }
}

Object js_eval(Object o)
{
  if (js==null)
  {    
    return null;
  }
  try 
  {
    return js.eval(o.toString());
  }
  catch(Exception e)
  {
    p_("ERR: error evaluating js: "+e.getMessage());
  }

  return null;
}

/**
 * Checks to see if a specific port is available.
 *
 * @param port the port to check for availability
 *
 * http://stackoverflow.com/questions/434718/sockets-discover-port-availability-using-java
 */
public static boolean checkIfPortAvail(int port) 
{
  ServerSocket ss = null;
  DatagramSocket ds = null;
  try {
    ss = new ServerSocket(port);
    ss.setReuseAddress(true);
    ds = new DatagramSocket(port);
    ds.setReuseAddress(true);
    return true;
  } 
  catch (IOException e) 
  {
  } 
  finally 
  {
    if (ds != null) 
    {
      ds.close();
    }

    if (ss != null) 
    {
      try {
        ss.close();
      } 
      catch (IOException e) 
      {
        /* should not be thrown */
      }
    }
  }
  return false;
} //end checkIfPortAvail

//===========================================================
void createGlobalGui()
{
  size(w, h);
  frame.setResizable(true);

  oldWidth = width;
  oldHeight = height;

  cp5 = new ControlP5(this);
  cp5.disableShortcuts();

  if (!sFontName.equals(""))
  {
    PFont font=createFont(sFontName, fontSize);
    cf1 = new ControlFont(font);
  }
  else
  {
    PFont font=createFont("data"+sPathSeparator+"font"+sPathSeparator+"VeraMono.ttf", fontSize);
    cf1 = new ControlFont(font);
  }

  cp5.setControlFont(cf1);

  txt1 = cp5.addTextarea("txt")
    .setPosition(5, 30)
      .setSize(w-20, console_height)
        .setFont(cf1)       
          .setLineHeight(fontSize+2)
            .setColor(color(200))
              .setColorBackground(color(0, 0))
                .setColorForeground(color(255, 100));

  console = cp5.addConsole(txt1);

  cp5.addTextlabel("label_info")
    .setText("OSCC - Open Sound Control Console       OSC port:"+osc_server_port)
      .setPosition(20, 5)
        .setColorValue(0xffffffff)
          ;

  t1=cp5.addTextfield("input")
    .setPosition(5, h-30)
      .setSize(w-10, 30)
        .setFont(cf1)
          .setFocus(true)
            .setColor(color(255, 255, 255))
              .setLabel("")
                ;

  t2=cp5.addTextfield("send_to_host")
    .setPosition(5, h-60)
      .setSize(w/2-2, 30)
        .setFont(cf1)
          .setFocus(false)
            .setColor(color(255, 255, 255))
              .setLabel("")
                .setAutoClear(false)
                  .setText(send_to_host)
                    ;

  t3=cp5.addTextfield("send_to_port")
    .setPosition(w/2, h-60)
      .setSize(w/2-2, 30)
        .setFont(cf1)
          .setFocus(false)
            .setColor(color(255, 255, 255))
              .setLabel("")
                .setAutoClear(false)
                  .setText(send_to_port)
                    ;

  //     addMouseWheelListener();
}

// ===========================================================================
void draw() 
{
  background(20);
  noStroke();

  if (width != oldWidth || height != oldHeight) 
  {       
    console_height=height-other_height;
    txt1.setSize(width-20, console_height);

    t1.setPosition(5, height-30)
      .setSize(width-10, 30)
        ;

    t2.setPosition(5, height-60)
      .setSize(width/2-2, 30)
        ;

    t3.setPosition(width/2, height-60)
      .setSize(width/2-2, 30)
        ;

    oldWidth = width;
    oldHeight = height;
  }

  //needed to 'autoflush' textarea
  if (!is_paused)
  {
    txt1.scroll(1.0);
  }
}

//===========================================================
void p_(Object o)
{
  if (is_log_enabled && pwriter!=null)
  {
    pwriter.println(year()+month_()+day_()+" "+hour_()+":"+minute_()+":"+second_()+" "+o);
    pwriter.flush();
  }

  if(!is_print_enabled)
  {
    return;
  }
  
  txt_lines_count++;
  if (txt_lines_count>=txt_max_lines)
  {
    txt_lines_count=0;
    console.clear();
  }
  println(hour_()+":"+minute_()+":"+second_()+" "+o);
}

String month_()
{
  return leadingZero(month());
}

String day_()
{
  return leadingZero(day());
}

String hour_()
{
  return leadingZero(hour());
}

String minute_()
{
  return leadingZero(minute());
}

String second_()
{
  return leadingZero(second());
}

String leadingZero(int i)
{
  if (i<10)
  {
    return "0"+i;
  }
  else
  {
    return ""+i;
  }
}

// ===========================================================================
void keyPressed() 
{
  // p_(keyCode);
  if (keyCode==TAB )
  {
    if (t1.isFocus())
    {
      t1.setFocus(false);
      t2.setFocus(true);
    }
    else if (t2.isFocus())
    {
      t2.setFocus(false);
      t3.setFocus(true);
    }
    else if (t3.isFocus())
    {
      t3.setFocus(false);
      t1.setFocus(true);
    }
  }
} //end keypressed

void endNow()
{
  //call shutdown hook (method must exist in oscc_scripts.js)
  js_eval("shutdownHook()");

  if (pwriter!=null)
  {
    pwriter.flush();
    pwriter.close();
  }
  if (oscP5!=null)
  {
    oscP5.stop();
  }
  exit2();
}

// ===========================================================================
void showHelp()
{
  StringBuffer sb=new StringBuffer();
  sb.append(sLineEnd);
  sb.append("OSCC help"+sLineEnd);
  sb.append(sLineEnd);

  sb.append("Command line params:"+sLineEnd);
  sb.append(sLineEnd);
  sb.append("   ./oscc help"+sLineEnd);
  sb.append("   ./oscc <my port>"+sLineEnd);  
  sb.append("   ./oscc <my port> <remote host> <remote port>"+sLineEnd);
  sb.append("   ./oscc <my port> <remote host> <remote port> <font name> <font size>"+sLineEnd);  
  sb.append("   ./oscc 10001"+sLineEnd);
  sb.append("   ./oscc 10001 10.10.10.22 1234"+sLineEnd);
  sb.append("   ./oscc 10001 10.10.10.22 1234 \"Bitstream Vera Sans Mono\" 14"+sLineEnd);  
  sb.append(sLineEnd); 
  sb.append("    Note: a remote client will see source port="+osc_server_port+" (my port) in messages sent by me."+sLineEnd);
  sb.append(sLineEnd);

  sb.append("Built-in commands without arguments:"+sLineEnd);
  sb.append(sLineEnd);  
  sb.append("   clear         cl:   clear console"+sLineEnd); 
  //sb.append("  pause    pa:   no output to console"+sLineEnd);
  //sb.append("  play     pl:   output to console"+sLineEnd);
  sb.append("   disable       di:   do not process incoming OSC messages"+sLineEnd);
  sb.append("   enable        en:   process incoming OSC messages"+sLineEnd);
  sb.append("   disable_print dp:   do not print anything to console"+sLineEnd);
  sb.append("   enable_print  ep:   print to console what's going on"+sLineEnd);  
  sb.append("   log           lo:   start logging to file"+sLineEnd);  
  sb.append("   nolog         nl:   stop logging to file"+sLineEnd);
  sb.append("   reload        rl:   reload actions configuration file"+sLineEnd);
  sb.append("   reloadjs      rj:   reload JavaScript file"+sLineEnd);  
  sb.append("   info          in:   show info on status (enabled/disabled etc.)"+sLineEnd);  
  sb.append("   about         ab:   additional info"+sLineEnd);
  sb.append("   quit           q:   quit"+sLineEnd);  
  sb.append("   help           h:   this help text"+sLineEnd);
  sb.append(sLineEnd);

  sb.append("How to set size of console font:"+sLineEnd);
  sb.append(sLineEnd);
  sb.append("   fontsize:<size>"+sLineEnd);
  sb.append("   fontsize:20"+sLineEnd);  
  sb.append(sLineEnd);

  sb.append("How to send an OSC message:"+sLineEnd);
  sb.append(sLineEnd);
  sb.append("   <pattern>(;<typetag>;<param 1>(;<param n>))"+sLineEnd);    
  sb.append("   /hi/there"+sLineEnd);  
  sb.append("   /hi/with/params;sif;this is a string;1234;88.99"+sLineEnd);
  sb.append("   OSC message must start with '/'"+sLineEnd);
  sb.append(sLineEnd);

  sb.append("How to run native (platform-specific) commands"+sLineEnd);
  sb.append(sLineEnd); 
  sb.append("   local:<your command>"+sLineEnd);
  sb.append("   local:oscsend localhost 10001 /test/from/ext/proc i 1"+sLineEnd);
  sb.append("   Output of command to stdout/stderr will NOT be visible in oscc"+sLineEnd);   
  sb.append(sLineEnd); 

  sb.append("How to trig actions on messages matching XYZ"+sLineEnd);
  sb.append(sLineEnd);  
  sb.append("See comments in file "+config+" on how to hook up actions to incoming OSC messages."+sLineEnd);
  sb.append("With actions, you can run native commands on your platform or trigger JavaScript functions."+sLineEnd);
  sb.append(sLineEnd);

  sb.append("How to evaluate JavaScript from the console:"+sLineEnd);
  sb.append(sLineEnd);  
  sb.append("   js:<your JavaScript>"+sLineEnd);
  sb.append("   js:a=42;println(a);"+sLineEnd);
  sb.append("   js:my_loaded_function(99);"+sLineEnd); 
  sb.append(sLineEnd);
  sb.append("How to send OSC message from JavaScript:"+sLineEnd);
  sb.append(sLineEnd);  
  sb.append("   oscc.send('10.10.10.20',1234,'/hi/from/js;sif;a string;1;2.3');"+sLineEnd);
  sb.append(sLineEnd);
  sb.append("How to print to console from JavaScript:"+sLineEnd);
  sb.append(sLineEnd);  
  sb.append("   oscc.p('hello from javascript');"+sLineEnd);
  sb.append(sLineEnd);
  sb.append("How to run native command from JavaScript:"+sLineEnd);
  sb.append(sLineEnd);  
  sb.append("   oscc.runCmd('echo 1 > /tmp/00001.tmp')"+sLineEnd);
  sb.append(sLineEnd);  

  sb.append("JavaScript is loaded from file "+sJsUri+sLineEnd);
  sb.append("JavaScript must comply to ECMA (without object 'window' etc.) "+sLineEnd);  
  sb.append(sLineEnd);  

  sb.append("How to use oscc for setting/getting status information:"+sLineEnd);  
  sb.append(sLineEnd);
  sb.append("Basically the JavaScript context can be used for that. But you can also store OSC messages directly."+sLineEnd);  
  sb.append("An OSC message with it's pattern and arguments is a good container to store small, structured information like status."+sLineEnd);  
  sb.append("External processes can store and retrieve OSC messages in oscc."+sLineEnd);
  sb.append(sLineEnd);
  sb.append("   //set/my/struct/as/osc/msg;sif;a string;1;2.3"+sLineEnd);  
  sb.append("   //get/my/struct/as/osc/msg"+sLineEnd);  
  sb.append(sLineEnd);

  sb.append("How to use oscc as a relay from the command line:"+sLineEnd);  
  sb.append(sLineEnd);
  sb.append("Temporary external processes can relay messages via oscc."+sLineEnd);
  sb.append("If the target will reply to sender, oscc will recieve it."+sLineEnd);  
  sb.append(sLineEnd);
  sb.append("   //send/<pattern> si<more> <host> <port> <payload1> <payload2>.."+sLineEnd);  
  sb.append("   oscsend //send/my/pattern sis \"10.10.10.20\" 1234 \"my payload\""+sLineEnd);
  sb.append(sLineEnd);

  sb.append("How to setup a poller from JavaScript:"+sLineEnd);  
  sb.append(sLineEnd);
  sb.append("Only one poller can be used at the moment."+sLineEnd);  
  sb.append(sLineEnd);  
  sb.append("   setPoller(host,port,osccommand,interval)"+sLineEnd);  
  sb.append("   setPoller('localhost',7777,'/hello;s;there',500)"+sLineEnd);
  sb.append(sLineEnd);
  sb.append("Stop/remove the poller:"+sLineEnd);  
  sb.append(sLineEnd);
  sb.append("   destroyPoller()"+sLineEnd);  
  sb.append(sLineEnd);  
  
  sb.append("Console log prefixes:"+sLineEnd);
  sb.append(sLineEnd);  
  sb.append("   INF: info"+sLineEnd);
  sb.append("   LDA: (re)load actions file"+sLineEnd);
  sb.append("   LDJ: (re)load JavaScript file"+sLineEnd);
  sb.append("   ADJ: add JavaScript action"+sLineEnd);
  sb.append("   ADS: add shell / native action"+sLineEnd);
  sb.append("   CNF: configuration setting enable/disable"+sLineEnd);
  sb.append("   SND: send OSC message"+sLineEnd);
  sb.append("   RCV: receive OSC message"+sLineEnd);
  sb.append("   JSE: evaluate JavaScript"+sLineEnd);
  sb.append("   JSR: return from JavaScript evaluation"+sLineEnd);  
  sb.append("   JSP: print to console from JavaScript"+sLineEnd);
  sb.append("   ADM: add message to store (//set)"+sLineEnd);  
  sb.append("   GTM: get message from store (//get)"+sLineEnd);
  sb.append("   CMD: native command"+sLineEnd);
  sb.append("   ERR: error"+sLineEnd);
  sb.append(sLineEnd);

  println(sb);
}

// ===========================================================================
void showAbout()
{
  StringBuffer sb=new StringBuffer();
  sb.append(sLineEnd);  
  sb.append("OSCC v"+sVersion+" about"+sLineEnd);
  sb.append(sLineEnd);  
  sb.append("OSCC stands for Open Sound Control Console and is built with Processing:"+sLineEnd);
  sb.append(sLineEnd);
  sb.append("http://www.processing.org"+sLineEnd);
  sb.append(sLineEnd);
  sb.append("OSCC uses controlP5 and oscP5 libraries:"+sLineEnd);
  sb.append(sLineEnd);
  sb.append("http://www.sojamo.de/libraries/controlP5"+sLineEnd);
  sb.append("http://www.sojamo.de/libraries/oscP5"+sLineEnd);
  sb.append(sLineEnd);
  sb.append("2013-01-18, thomas brand, tom@trellis.ch"+sLineEnd);
  sb.append("credits to seablade,las,hairmare,rgareus,oofus!"+sLineEnd);
  //sb.append(""+sLineEnd);
  sb.append(sLineEnd); 
  println(sb);
}

// ===========================================================================
/*
void addMouseWheelListener() 
 {
 frame.addMouseWheelListener(new java.awt.event.MouseWheelListener() 
 {
 public void mouseWheelMoved(java.awt.event.MouseWheelEvent e) 
 {
 cp5.setMouseWheelRotation(e.getWheelRotation());
 }
 }
 );
 }
 */

// ===========================================================================
void oscEvent(OscMessage msg) 
{
  if (!is_enabled)
  {
    return;
  }

  //pretty print incoming
  StringBuffer sb=new StringBuffer();
  sb.append("RCV: "+msg.netAddress()+" "+msg.addrPattern()+" "+msg.typetag()+" ");

  Object[] o=msg.arguments();
  for (int i=0;i<o.length;i++)
  {
    //enclose strings in quotes
    if (msg.typetag().substring(i, i+1).equals("s"))
    {
      sb.append("\""+o[i]+"\" ");
    }
    else
    {
      sb.append(o[i]+" ");
    }
  }
  p_(sb);

  //set //get mechanism - use oscc as message store
  if (msg.addrPattern().startsWith("//set/"))
  {
    p_("ADM: adding message to store");
    //strip pattern prefix
    String pat=msg.addrPattern();
    String sendpat=pat.substring("//set/".length(), pat.length());

    messageStore.put("/"+sendpat, msg);

    //bash: for i in {1..100}; do oscsend localhost 10001 //set/val/$i i $RANDOM; done
  }
  else if (msg.addrPattern().startsWith("//get/"))
  {
    //strip pattern prefix
    String pat=msg.addrPattern();
    String sendpat=pat.substring("//get/".length(), pat.length());

    OscMessage om = messageStore.get("/"+sendpat);
    if (om!=null)
    {
      p_("GTM: getting message from store");

      NetAddress a=new NetAddress(msg.netaddress()); 
      oscP5.send("/"+sendpat, om.arguments(), a);
    }
    else
    {
      p_("ERR: nothing found in store");
      Object[] empty=new Object[0];
      NetAddress a=new NetAddress(msg.netaddress()); 
      oscP5.send("/not/found", empty, a);
    }
    //bash: for i in {1..100}; do oscsend localhost 10001 //send//get/val/$i si 127.0.0.1 10001; done
  }

  //resend mechanism - send from anywhere to oscc, oscc will relay it
  else if (msg.addrPattern().startsWith("//send/") && msg.typetag().startsWith("si")
    //if not sent from console
  && msg.netaddress().port()!=osc_server_port
    )         
  {
    String pat=msg.addrPattern();
    String type=msg.typetag();

    //strip pattern prefix
    String sendpat=pat.substring("//send/".length(), pat.length());

    //strip type prefix
    String sendtype=type.substring("si".length(), type.length());

    //     Object[] o=msg.arguments();
    Object[] osend=new Object[o.length-2];

    //strip destination host and port from args  
    //arraycopy(Object src, int srcPos, Object dest, int destPos, int length) 
    arraycopy(o, 2, osend, 0, osend.length);

    if (sendpat.length()>0)
    {
      NetAddress a=new NetAddress(msg.get(0).stringValue(), 
      msg.get(1).intValue());
      oscP5.send("/"+sendpat, osend, a);

      sb=new StringBuffer();
      sb.append("SND: "+a.toString()+" /"+sendpat+" "+sendtype+" ");

      for (int i=0;i<osend.length;i++)
      {        
        //enclose strings in quotes
        if (sendtype.substring(i, i+1).equals("s"))
        {
          sb.append("\""+osend[i]+"\" ");
        }
        else
        {
          sb.append(osend[i]+" ");
        }
      }
      p_(sb);
    }
  }
  else
  {
    //================
    triggerAllFor(msg);
  }
} //end osc event

// ===========================================================================
//from text fields
void controlEvent(ControlEvent ev) 
{
  if (ev.isAssignableFrom(Textfield.class)) 
  {
    if (ev.getName().equals("input"))
    { 
      String s=ev.getStringValue().trim();

      if (s.equals(""))
      {
        //do nothing
      }
      else if (s.equals("clear") || s.equals("cl"))
      {
        console.clear();
      }
      else if (s.equals("disable") || s.equals("di"))
      {
        p_("CNF: disabling processing of incoming osc messages ('en' to enable again)");
        is_enabled=false;
      }
      else if (s.equals("enable") || s.equals("en"))
      {
        p_("CNF: enabling processing of incoming osc messages");
        is_enabled=true;
      }
      else if (s.equals("disable_print") || s.equals("dp"))
      {
        p_("CNF: disabling printing to console ('ep' to enable again)");
        is_print_enabled=false;
      }
      else if (s.equals("enable_print") || s.equals("ep"))
      {
        is_print_enabled=true;
        p_("CNF: enabling printing to console");
      }
      
      /*
      else if (s.equals("pause") || s.equals("pa"))
       {
       p_("--PAUSE-- enter 'play' to start");
       is_paused=true;
       console.pause();
       }
       else if (s.equals("play") || s.equals("pl"))
       {
       is_paused=false;
       console.play();
       println();
       p_("--PLAY--");
       }
       */
      else if (s.equals("log") || s.equals("lo"))
      {
        //if first time
        if (pwriter==null)
        {
          sLogFilename="oscc_"+year()+month_()+day_()+"_"+hour_()+minute_()+second_()+".log";
          pwriter=createWriter(sLogDir+sLogFilename);
        }
        p_("CNF: enabling log to file "+sLogDir+sLogFilename);
        is_log_enabled=true;
      }
      else if (s.equals("nolog") || s.equals("nl"))
      {
        p_("CNF: disabling log to file "+sLogDir+sLogFilename);
        if (pwriter!=null)
        {
          pwriter.flush();
          pwriter=null;
        }
        is_log_enabled=false;
      }
      else if (s.equals("reload") || s.equals("rl"))
      {
        p_("LDA: reloading actions config from: "+config);
        parseConfig(config);
      }
      else if (s.equals("reloadjs") || s.equals("rj"))
      {
        p_("LDJ: reloading JavaScript from: "+sJsUri);
        loadScripts();
      }

      else if (s.startsWith("fontsize:"))
      {        
        try
        {
          fontSize=Integer.parseInt(s.substring("fontsize:".length(), s.length()));
        }
        catch (Exception e)
        {
          p_("ERR: error setting fontsize");
          return;
        }
        if (!sFontName.equals(""))
        {
          PFont font=createFont(sFontName, fontSize);
          cf1 = new ControlFont(font);
        }
        else
        {
          PFont font=createFont("data"+sPathSeparator+"font"+sPathSeparator+"VeraMono.ttf", fontSize);
          cf1 = new ControlFont(font);
        }
        cp5.setControlFont(cf1);
        txt1.setFont(cf1);
        t1.setFont(cf1);
        t2.setFont(cf1);
        t3.setFont(cf1);  
        p_("CFG: new font size is "+fontSize);
      }

      //evaluate javascript
      else if (s.startsWith("js:"))
      {
        String script=s.substring("js:".length(), s.length());
        if (script.length()>0)
        {
          p_("JSE: "+script);
          Object o=js_eval(script);
          if (o!=null)
          {
            p_("JSR: "+o);
          }
        }
      }
      //run natively
      else if (s.startsWith("local:"))
      {
        String cmd_string=s.substring("local:".length(), s.length());
        if (cmd_string.length()>0)
        {
          p_("CMD: "+cmd_string);

          cmd.setCmd(cmd_string);
          cmd.run();
        }
      }
      else if (s.equals("info") || s.equals("in"))
      {
        print("processing of incoming osc messages is ");
        if (is_enabled)
        {
          println("ENABLED");
        }
        else
        {
          println("DISABLED");
        }
        print("logging to file is ");
        if (is_log_enabled)
        {
          println("ENABLED: "+sLogDir+sLogFilename);
        }
        else
        {
          println("DISABLED");
        } 
        println("platform is "+os.toUpperCase());
        println("found "+vActions.size()+" configured actions in "+config);
        println("oscc version v"+sVersion);
      }
      else if (s.equals("about") || s.equals("ab"))
      {
        showAbout();
      }
      else if (s.equals("quit") || s.equals("q"))
      {
        endNow();
      }
      else if (s.equals("help") || s.equals("h"))
      {
        showHelp();
      }
      //if is mesage to send via osc
      else if (s.startsWith("/"))
      {         
        send_osc(t2.getText(), Integer.parseInt(t3.getText()), s);
      }
      else
      {
        p_("ERR: command not found: "+s);
      }
    }
  }
} //end control event

// ===========================================================================
//supported types: s(tring), i(int), f(loat)
void send_osc(String host, int port, String s)
{
  String[] parts=s.split(";");
  String sPattern="";
  String typetag="";

  if (parts.length>0)
  {
    sPattern=parts[0];
  }
  else
  {
    return;
  }
  if (parts.length >= 3)
  {
    typetag=parts[1];
  }
  try 
  {
    //NetAddress a=new NetAddress(t2.getText(), Integer.parseInt(t3.getText()));
    NetAddress a=new NetAddress(host, port);

    OscMessage oscm = new OscMessage(sPattern);

    StringBuffer sb=new StringBuffer();

    for (int h=0;h<typetag.length();h++)
    {
      if (typetag.substring(h, h+1).equals("i"))
      {
        sb.append(parts[2+h]+" ");
        oscm.add(Integer.parseInt(parts[2+h]));
      }
      else if (typetag.substring(h, h+1).equals("f"))
      {
        sb.append(parts[2+h]+" ");
        oscm.add(Float.parseFloat(parts[2+h]));
      }
      else if (typetag.substring(h, h+1).equals("s"))
      {
        sb.append(parts[2+h]+" ");
        oscm.add(parts[2+h]);
      }
    }

    p_("SND: "+a.toString()+" "+sPattern+" "+typetag+" "+sb);
    oscP5.send(oscm, a);
  }
  catch (Exception e) 
  {
    p_("ERR: boom! wrong param count? invalid int, float or port value?");
  }
}

// ===========================================================================

private void triggerAllFor(OscMessage msg)
{
  String spat=msg.addrPattern();
  //for (int i=0;i<vActions.size();i++)
  for (OSCAction oa : vActions)
  {
    //OSCAction oa=(OSCAction)vActions.elementAt(i);

    if (regex.isMatch(spat, oa.getPattern(),is_print_enabled))
    {
      //regex will print out used match pattern
      String sCmd=oa.getAction();

      Object[] args=msg.arguments();

      if (oa.getType()==0)
      {
        //SHELLSCRIPT

        //if passparams 1, add params to cmd string
        if (oa.getPass()>=10)
        {
          sCmd=sCmd+" "+spat+" "+msg.netAddress().address()+" "+msg.netAddress().port();
          //sParams="'" + spat + "','" + msg.netAddress().address() + "'," +msg.netAddress().port();
        }
        if (oa.getPass()>=11 || oa.getPass()==1)
        {

          for (int j=0;j<args.length;j++)
          {
            sCmd=sCmd+" \""+args[j]+"\"";
          }
        }
        p_("CMD: running "+sCmd);
        cmd.setCmd(sCmd);
        cmd.run();
        p_("CMD: exit status was "+cmd.getExitStatus());
      }
      else
      {
        //JAVASCRIPT


        String sParams="";
        //if passparams 1, add params to cmd string
        if (oa.getPass()>=10)
        {
          sParams="'" + spat + "','" + msg.netAddress().address() + "'," +msg.netAddress().port();
        }
        if (oa.getPass()>=11)
        {
          for (int j=0;j<args.length;j++)
          {            
            sParams+=",'"+args[j]+"'";
          }
        }
        else if
          (oa.getPass()==1)
        {
          for (int j=0;j<args.length;j++)
          {
            if (j>0)
            {
              sParams+=",";
            }
            sParams+="'"+args[j]+"'";
          }
        }

        sCmd=sCmd.substring(0, sCmd.length()-2)+"("+sParams+");";

        p_("JSE: "+sCmd);
        Object o=js_eval(sCmd);
        if (o!=null)
        {
          p_("JSR: "+o);
        }
      }
    }
  }
} //end triggerallfor

// ===========================================================================
public boolean parseConfig(String sConfigUri)
{
  prefs=loadStrings(sConfigUri);
  vActions=new Vector<OSCAction>();

  if (prefs==null)
  {
    p_("ERR: invalid osc config file.");
    return false;
  }

  if (prefs.length>1)
  {

    //parse again for actions
    for (int i=0;i<prefs.length;i++)
    {
      //ignore comments # + ;
      if (prefs[i].startsWith("#") || prefs[i].startsWith(";") || prefs[i].equals(""))
      {
        continue;
      }

      String[] parts= prefs[i].split(";");
      if (parts.length>1)
      {
        int iPassParams=0;
        if (parts.length>2)
        {
          try
          {
            //bit-format
            //00 01 10 11
            iPassParams=Integer.parseInt(parts[2]);
          }
          catch(Exception e) 
          {
            p_("ERR: invalid passparams.");
          }
        }

        String sPattern=parts[0];
        //replace *  //anything following
        Pattern replace = Pattern.compile("[*]");
        Matcher matcher = replace.matcher(sPattern);
        String sPatternExtended=matcher.replaceAll("[a-zA-Z0-9-/]*");
        //replace +  //anything up to next /
        replace = Pattern.compile("[+]");
        matcher = replace.matcher(sPatternExtended);
        sPattern=matcher.replaceAll("[a-zA-Z0-9-]*");
        //replace ?  //any single char
        replace = Pattern.compile("[?]");
        matcher = replace.matcher(sPattern);
        sPatternExtended=matcher.replaceAll("[a-zA-Z0-9-]");
        //replace #  //any number sequence
        replace = Pattern.compile("[#]");
        matcher = replace.matcher(sPatternExtended);
        sPattern=matcher.replaceAll("[0-9]+");

        String sAction=parts[1];
        if (sAction.length()>2 && sAction.substring(sAction.length()-2, sAction.length()).equals("()"))
        {
          p_("ADJ: adding "+sPattern+" -> "+sAction+" ("+iPassParams+")  JAVASCRIPT");
          vActions.add(new OSCAction(parts[0], sPattern, sAction, iPassParams, 1));
        }
        else
        {
          p_("ADS: adding "+sPattern+" -> "+sAction+" ("+iPassParams+")  SHELLSCRIPT");
          vActions.add(new OSCAction(parts[0], sPattern, sAction, iPassParams, 0));
        }
      }
      else
      {
        //maybe empty line
      }
    } //end for
  }//end if prefs.length>1
  else 
  {
    p_("ERR: no configured actions found.");
  }

  return true;
}

// ===========================================================================
public class OSCAction
{
  String patternOrig="";
  String pattern="";
  String action="";
  int pass=0;

  //0: shell script
  //1: java script
  int type=0;

  public OSCAction(String s1, String s2, String s3, int i1, int i2)
  {
    patternOrig=s1;
    pattern=s2;
    action=s3;
    pass=i1;
    type=i2;
  }
  public String getPattern()
  {
    return pattern;
  }
  public String getAction()
  {
    return action;
  }
  public int getPass()
  {
    return pass;
  }
  public int getType()
  {
    return type;
  }
  public String getConfigurationLine()
  {
    return patternOrig+";"+action+";"+pass;
  }
} //end OSCAction


// ===========================================================================
public class TrashCollector extends Thread 
{
  int interval=5000;
  public TrashCollector()
  {
  }
  public TrashCollector(int i)
  {
    interval=i;
  }
  public void setInterval(int i)
  {
    interval=i;
  }
  public void run() 
  {
    while (true)
    {
      try 
      { 
        System.gc();
        Thread.sleep(interval);
      } 
      catch (Exception ex) 
      {
      }
    }
  }
}
//end inner class trashcollector


//helper
String getAsString(String sFile)
{

  BufferedReader reader = createReader(sFile);

  StringBuffer content = new StringBuffer();
  String sLine="";

  try {

    while (sLine!=null)
    {
      sLine=reader.readLine();
      if (sLine!=null)
      {
        content.append(sLine);
      }
    }
  } 
  catch (IOException e) {
    e.printStackTrace();
  }

  return content.toString();
}

// ===========================================================================
//make visible java functions to javascript over wrapper / API class
public class OSCC_API
{
  RunCmd jsCmd=new RunCmd();
  public void p(String s)
  {
    p_("JSP: "+s);
  }
  public void send(String host, int port, String msg)
  {
    send_osc(host, port, msg);
  }
  public void loadJavaScript(String s)
  {
    p_("LDJ: "+s);
    js_eval(getAsString(s));    
  }
  public Object[] get(String pat)
  {
    OscMessage om = messageStore.get(pat);
    if (om!=null)
    {
      //return "found";
      return om.arguments();
    }
    return null;
  }
  public void runCmd(String s)
  {
    jsCmd.setCmd(s);
    jsCmd.run();
  }
  public void setPoller(String host, int port, String action, int interval)
  {
    if(poller!=null)
    {
      poller.stopNow();
    }
    
    p_("PLL: setting up poller: "+host+":"+port+" "+action+" - every "+interval+" msec");
    
    poller=new Poller();
    poller.setHost(host);
    poller.setPort(port);
    poller.setAction(action);
    poller.setDelay(interval);
    poller.start();
  }
  public void destroyPoller()
  {
    if(poller!=null)
    {
      poller.stopNow();
      poller=null;
    }
  }
}

// ===========================================================================
void exit() 
{
  endNow();
}

void exit2()
{
  super.exit();
}

// ===========================================================================

public class Poller extends Thread 
{
  boolean do_stop=false;

  String host="127.0.0.1";
  int port=3819;
  String sOscAction="";
  int delay=500;

  public Poller()
  {
    //this.start();
  }
  
  public void setHost(String s)
  {
    host=s;
  }
  
  public void setPort(int i)
  {
    port=i;
  }
  
  public void setDelay(int i)
  {
    delay=i;
  }

  public void setAction(String s)
  {
    sOscAction=s;
  }

  public void stopNow()
  {
    do_stop=true;
  }

  public void run() {
    
    try { 
      while (!do_stop)
      {
        p_("PLL: "+delay);
        send_osc(host, port, sOscAction);
        Thread.sleep(delay);
      }      
    } 
    catch (Exception ex) {
      //      System.out.println(ex.toString());
    }
  }
}
//end inner class poller

