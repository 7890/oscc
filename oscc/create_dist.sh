#!/bin/sh

#//tb/131115

#this script uses the exported folders from Processing
#in this directory. 
#start the script from where it is stored (here:).
#it strips off unused content and makes minor changes
#to the startup scripts using files from the 
#directories "windows", "linux" and "macosx"
#resulting compressed files will be put to $relase_dir
#bskt oscc_lin32 and oscc_lin64 in $release_dir will 
#be updated with new oscc_*.tgz

release_dir="../dist"

echo "did you export the application to win/mac/linux? ctrl+c to abort"
read a

release_string=`date +"%s"`

#############################3

if [ -d application.linux32 ]
then

echo "creating lin32 distributable"

rel="oscc_lin32_""$release_string"
cp -r application.linux32 "$rel"

rm "$rel"/lib/gluegen*
rm "$rel"/lib/jogl*
rm -rf "$rel""/source"

cp oscc_release_notes.txt "$rel"
cp linux/oscc "$rel"

tar cfvz "$rel"".tgz" "$rel"

"$release_dir"/oscc_lin32 deleteat 1
"$release_dir"/oscc_lin32 add "$rel"".tgz"

rm -rf "$rel"
mv "$rel"".tgz" "$release_dir"

fi

#############################3

if [ -d application.linux64 ]
then

echo "creating lin64 distributable"

rel="oscc_lin64_""$release_string"
cp -r application.linux64 "$rel"

rm "$rel"/lib/gluegen*
rm "$rel"/lib/jogl*
rm -rf "$rel""/source"

cp oscc_release_notes.txt "$rel"
cp linux/oscc "$rel"

tar cfvz "$rel"".tgz" "$rel"

"$release_dir"/oscc_lin64 deleteat 1
"$release_dir"/oscc_lin64 add "$rel"".tgz"

rm -rf "$rel"
mv "$rel"".tgz" "$release_dir"

fi

#############################3

if [ -d application.windows32 ]
then

echo "creating win32 distributable"

rel="oscc_win32_""$release_string"
cp -r application.windows32/ "$rel"

rm "$rel"/lib/gluegen*
rm "$rel"/lib/jogl*
rm -rf "$rel""/source"

rm "$rel"/lib/args.txt
rm -f "$rel"/oscc.exe

cp oscc_release_notes.txt "$rel"
cp windows/oscc.bat "$rel"

zip -r "$rel"".zip" "$rel"

rm -rf "$rel"
mv "$rel"".zip" "$release_dir"

fi

#############################3

if [ -d application.windows64 ]
then

echo "creating win64 distributable"

rel="oscc_win64_""$release_string"
cp -r application.windows64/ "$rel"

rm "$rel"/lib/gluegen*
rm "$rel"/lib/jogl*
rm -rf "$rel""/source"

rm "$rel"/lib/args.txt
rm -f "$rel"/oscc.exe

cp oscc_release_notes.txt "$rel"
cp windows/oscc.bat "$rel"

zip -r "$rel"".zip" "$rel"

rm -rf "$rel"
mv "$rel"".zip" "$release_dir"

fi

#############################

if [ -d application.macosx ]
then

echo "creating macosx distributable"

rel="oscc_macosx_""$release_string"
cp -r application.macosx/ "$rel"

rm "$rel"/oscc.app/Contents/Resources/Java/gluegen*
rm "$rel"/oscc.app/Contents/Resources/Java/jogl*

rm -rf "$rel""/source"

cp oscc_release_notes.txt "$rel"
cp macosx/Info.plist "$rel"/oscc.app/Contents/

zip -r "$rel"".zip" "$rel"

rm -rf "$rel"
mv "$rel"".zip" "$release_dir"

fi

#############################

ls -l "$release_dir"

exit

