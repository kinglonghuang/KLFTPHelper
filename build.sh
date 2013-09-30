#/*
#* https://github.com/kinglonghuang/KLFTPHelper
#*
#* BSD license follows (http://www.opensource.org/licenses/bsd-license.php)
#*
#* Copyright (c) 2013 KLStudio.(kinglong.huang) All Rights Reserved.
#*
#* Redistribution and use in source and binary forms, with or without modification,
#* are permitted provided that the following conditions are met:
#*
#* Redistributions of  source code  must retain  the above  copyright notice,
#* this list of  conditions and the following  disclaimer. Redistributions in
#* binary  form must  reproduce  the  above copyright  notice,  this list  of
#* conditions and the following disclaimer  in the documentation and/or other
#* materials  provided with  the distribution.  Neither the  name of  Wei
#* Wang nor the names of its contributors may be used to endorse or promote
#* products  derived  from  this  software  without  specific  prior  written
#* permission.  THIS  SOFTWARE  IS  PROVIDED BY  THE  COPYRIGHT  HOLDERS  AND
#* CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT
#* NOT LIMITED TO, THE IMPLIED  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
#* A  PARTICULAR PURPOSE  ARE DISCLAIMED.  IN  NO EVENT  SHALL THE  COPYRIGHT
#* HOLDER OR  CONTRIBUTORS BE  LIABLE FOR  ANY DIRECT,  INDIRECT, INCIDENTAL,
#* SPECIAL, EXEMPLARY,  OR CONSEQUENTIAL DAMAGES (INCLUDING,  BUT NOT LIMITED
#* TO, PROCUREMENT  OF SUBSTITUTE GOODS  OR SERVICES;  LOSS OF USE,  DATA, OR
#* PROFITS; OR  BUSINESS INTERRUPTION)  HOWEVER CAUSED AND  ON ANY  THEORY OF
#* LIABILITY,  WHETHER  IN CONTRACT,  STRICT  LIABILITY,  OR TORT  (INCLUDING
#* NEGLIGENCE  OR OTHERWISE)  ARISING  IN ANY  WAY  OUT OF  THE  USE OF  THIS
#* SOFTWARE,   EVEN  IF   ADVISED  OF   THE  POSSIBILITY   OF  SUCH   DAMAGE.
#*
#*/

#!/bin/sh

############################ You can config between the# #####################
Target_Name=KLFTPHelper
Product_Name=${Target_Name}
SDK_Version=7.0
Configuration=Release
ReleaseFolderName=KLFTPHelper_Lib
##############################################################################

cd "$(dirname "$0")"
cd ./KLFTPHelper/
ARM_LIB_PATH=${PWD}/build/Release-iphoneos/lib${Product_Name}.a
ARM_HEADER_FOLDER_PATH=${PWD}/build/Release-iphoneos/include/${Product_Name}
I386_LIB_PATH=${PWD}/build/Release-iphonesimulator/lib${Product_Name}.a
I386_HEADER_FOLDER_PATH=${PWD}/build/Release-iphonesimulator/include/${Product_Name}
xcodebuild -target "${Target_Name}" -sdk iphoneos${SDK_Version} -configuration ${Configuration}
xcodebuild -target "${Target_Name}" -sdk iphonesimulator${SDK_Version} -configuration ${Configuration}

if [ -f "$ARM_LIB_PATH" ];then
if [ -f "$I386_LIB_PATH" ]; then

mkdir -p ./${ReleaseFolderName}/arm/KLFTPHelper/
mkdir -p ./${ReleaseFolderName}/arm/KLFTPHelper/Headers/
cp ${ARM_LIB_PATH} ./${ReleaseFolderName}/arm/KLFTPHelper/
cp -r ${ARM_HEADER_FOLDER_PATH}/* ./${ReleaseFolderName}/arm/KLFTPHelper/Headers/

mkdir -p ./${ReleaseFolderName}/i386/KLFTPHelper/
mkdir -p ./${ReleaseFolderName}/i386/KLFTPHelper/Headers/
cp ${I386_LIB_PATH} ./${ReleaseFolderName}/i386/KLFTPHelper/
cp -r ${I386_HEADER_FOLDER_PATH}/* ./${ReleaseFolderName}/i386/KLFTPHelper/Headers/

mkdir -p ./${ReleaseFolderName}/universal/KLFTPHelper/
mkdir -p ./${ReleaseFolderName}/universal/KLFTPHelper/Headers/
cp -r ${ARM_HEADER_FOLDER_PATH}/* ./${ReleaseFolderName}/universal/KLFTPHelper/Headers/
lipo -create ${ARM_LIB_PATH} ${I386_LIB_PATH} -o ./${ReleaseFolderName}/universal/KLFTPHelper/lib${Product_Name}.a

fi
fi

#do clear
rm -R "${PWD}"/build

cp -r ./${ReleaseFolderName} ..
rm -r ./${ReleaseFolderName}
