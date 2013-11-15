
```
oscc is built using Processing (processing.org) and uses two additional libs, controlP5 and oscP5

rebuild_controlP5 will recreate controP5-2.0.4.zip with a small change
chmod 755 rebuild_controlP5
./rebuild_controlP5

to see what will be changed, look at
./rebuild_controlP5 dump ControlFont.java

//txt.add(myString.substring(0, myString.length() - 1));
txt.add(myString.substring(0, PApplet.max(0,myString.length() - 1)));

-> this file will be replaced in controP5-2.0.4.zip
-> newly created controP5-2.0.4.1.zip contains new created controlP5.jar

install libraries for Processing (processing.org):

copy 'controP5-2.0.4.1.zip' and 'oscP5-0.9.8.zip' to '~/sketchbook/libraries' folder and unzip

in Processing, open oscc/oscc.pde

Libraries:

http://www.sojamo.de/libraries/controlP5/
http://www.sojamo.de/libraries/controlP5/download/controlP5-2.0.4.zip

<<
controlP5 is a library written by Andreas Schlegel for the programming environment processing. Last update, 12/23/2012.

ControlP5 is a GUI and controller library for processing that can be used in authoring, application, and applet mode. Controllers such as Sliders, Buttons, Toggles, Knobs, Textfields, RadioButtons, Checkboxes amongst others are easily added to a processing sketch. They can be arranged in separate control windows, and can be organized in tabs or groups.
>>

http://www.sojamo.de/libraries/oscP5/
http://www.sojamo.de/libraries/oscP5/download/oscP5-0.9.8.zip

<<
oscP5 is a library written by Andreas Schlegel for the programming environment processing. Last update, 12/19/2011.

oscP5 is an OSC implementation for the programming environment processing. OSC is the acronym for Open Sound Control, a network protocol developed at cnmat, UC Berkeley.
Open Sound Control is a protocol for communication among computers, sound synthesizers, and other multimedia devices that is optimized for modern networking technology and has been used in many application areas. for further specifications and application implementations please visit the official osc site
>>

```