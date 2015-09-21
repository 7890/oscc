//tb/1010

import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class OSCRegexMatcher 
{
  //test
  public static void main(String[] args) 
  {
    OSCRegexMatcher regex=new OSCRegexMatcher();
    System.out.println(regex.isMatch(args[0], args[1], true));
    System.out.println(regex.isMatchSimple(args[0], args[1], true));
  }

  public OSCRegexMatcher()
  {
  }

  public boolean isMatch(String sInput, String sPattern, boolean verbose)
  {
    Pattern pattern = Pattern.compile(sPattern, Pattern.CASE_INSENSITIVE);
    Matcher matcher = pattern.matcher(sInput);

    boolean ret=matcher.matches();

    if(ret && verbose)
    {
      System.out.println("OSCRegexMatcher: This Pattern matched: "+sPattern);
    }

    return ret;
  }

  public boolean isMatchSimple(String sInput, String sPattern, boolean verbose)
  {
    //replace *
    Pattern replace = Pattern.compile("[*]");
    Matcher matcher = replace.matcher(sPattern);
    String sPatternExtended=matcher.replaceAll("[a-zA-Z0-9-/]*");
    //replace +
    replace = Pattern.compile("[+]");
    matcher = replace.matcher(sPatternExtended);
    String sPatternExtended2=matcher.replaceAll("[a-zA-Z0-9-]*");
    //replace ?
    replace = Pattern.compile("[?]");
    matcher = replace.matcher(sPatternExtended2);
    sPatternExtended=matcher.replaceAll("[a-zA-Z0-9-]");

    return isMatch(sInput, sPatternExtended, verbose);
  }
} //end class OSCRegexMatcher

