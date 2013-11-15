//tb/1010//1105
//minimal, linux/win32

import java.util.Vector;
import java.io.*;

public class RunCmd extends Thread 
{
  String sCmd="";
  int iExitStatus=-1;

  String os;
  boolean isUnix;
  boolean isWindows;
  boolean isMac;

  public RunCmd(String cmd)
  {
    sCmd=cmd;
    setOS();
  }    

  public RunCmd()
  {
    setOS();
  }

  public void setOS()
  {
    os = System.getProperty("os.name").toLowerCase();
    isUnix = os.indexOf("nix") >= 0 || os.indexOf("nux") >= 0;
    isWindows = os.indexOf("win") >= 0;
    isMac = os.indexOf("mac") >= 0;
  }

  public void setCmd(String cmd)
  {
    sCmd=cmd;
  }

  public int getExitStatus()
  {
    return iExitStatus;
  }

  public void run() 
  {
    //System.out.println("running "+sCmd);

    try 
    {
      //http://forums.devx.com/showthread.php?t=147403

      //create a process for the shell
      ProcessBuilder pb=null;

      if (isUnix || isMac)
      {
        pb = new ProcessBuilder("/bin/sh", "-c", sCmd);
      }
      else if (isWindows)
      {
        pb = new ProcessBuilder("cmd.exe", "/C", sCmd);
      }

      Process shell = pb.start();

      iExitStatus = shell.waitFor();
    } 
    catch (Exception ex) {
      System.out.println(ex.toString());
    }
  }
} //end class RunCmd

