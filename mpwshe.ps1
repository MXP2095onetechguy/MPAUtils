#!/usr/bin/env pwsh


# __  __ ______        ______  _   _ _____ 
# |  \/  |  _ \ \      / / ___|| | | | ____|
# | |\/| | |_) \ \ /\ / /\___ \| |_| |  _|  
# | |  | |  __/ \ V  V /  ___) |  _  | |___ 
# |_|  |_|_|     \_/\_/  |____/|_| |_|_____|
# 
# MPWSHE is a text editor, line oriented
# It is written in powershell
# MPWSHE means MXPSQL PoWerSHell Editor
# Licensed Under MIT License
# 
# You can edit and write
# Friendly commands
# Friendly error messages
# Can be used as a non-interactive editor
# Can fetch from the internet
#
# MIT License
# 
# Copyright (c) 2022 MXPSQL
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.



### Utils

# check if the module is installed and install if it is
# See https://www.powershellgallery.com/ for module and version info
Function CheckModule(
    [string] [Parameter(Mandatory = $true)] $moduleName,
    [string] $minimalVersion,
    [bool] $install = $true
) {
    $module = Get-Module -Name $moduleName -ListAvailable |`
        Where-Object { $null -eq $minimalVersion -or $minimalVersion -lt $_.Version } |`
        Select-Object -Last 1;
    if ($null -ne $module) {
         Write-Verbose ('Module {0} (v{1}) is available.' -f $moduleName, $module.Version);
    }
    else {
        Import-Module -Name 'PowershellGet';
        $installedModule = Get-InstalledModule -Name $moduleName -ErrorAction SilentlyContinue;
        if ($null -ne $installedModule) {
            Write-Verbose ('Module [{0}] (v {1}) is installed.' -f $moduleName, $installedModule.Version);
        }
        if (($null -eq $installedModule -or ($null -ne $minimalVersion -and $installedModule.Version -lt $minimalVersion)) -and $install) {
            Write-Verbose ('Module {0} min.vers {1}: not installed; check if nuget v2.8.5.201 or later is installed.' -f $moduleName, $minimalVersion);
            #First check if package provider NuGet is installed. Incase an older version is installed the required version is installed explicitly
            if ((Get-PackageProvider -Name NuGet -Force).Version -lt '2.8.5.201') {
                Write-Warning ('Module {0} min.vers {1}: Install nuget!' -f $moduleName, $minimalVersion);
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force;
            }        
            $optionalArgs = New-Object -TypeName Hashtable;
            if ($null -ne $minimalVersion) {
                $optionalArgs['RequiredVersion'] = $minimalVersion;
            }  
            Write-Warning ('Install module {0} (version [{1}]) within scope of the current user.' -f $moduleName, $minimalVersion);
            Install-Module -Name $moduleName @optionalArgs -Scope CurrentUser -Force -Verbose;
        } 
    }
}

function pager(){
    $TextFS = $args[0];
    $MaxLineToDisplay = $args[1];

    if(-not [String]::IsNullOrEmpty($TextFS)){
        $run = $true
        $line = 0;
        $maxLine = $TextFS.Split("`n").Length;

        if($MaxLineToDisplay -gt $maxLine){
            Write-Host $TextFs;
        }
        else{
            while($run){
                Clear-Host;
                $currMaxDispLine = 0;

                for($i = $line; $i -lt $line + $MaxLineToDisplay; $i++){
                    if($i -lt $MaxLine + 1){
                        Write-Host $TextFS.Split("`n")[$i];
                        $currMaxDispLine = $i + 1;
                    }
                }

                Write-Host $line"-"$currMaxDispLine"/"$maxLine "Press any key to continue or press q to quit.";
                $key = [System.Console]::ReadKey();
                if($key.KeyChar -eq "q" -or $key.Key -eq [ConsoleKey]::Escape){
                    $run = $false;
                }
                elseif($key.Key -eq [ConsoleKey]::DownArrow -or $key.Key -eq [ConsoleKey]::Enter){
                    if($line + $MaxLineToDisplay -lt $maxLine){
                        $line++;
                    }
                }
                elseif($key.Key -eq [ConsoleKey]::UpArrow){
                    if($line -gt 0){
                        $line--;
                    }
                }
            }
        }
    }
    else{
        Write-Host $TextFS;
    }
}

### main
$helpStr = @" 
MPWSHE.ps1 is a text editor, line oriented

    USAGE:
        ./mpwshe.ps1 [options]

    Options:     
        -f, --file file Open file
        -s, --script, script run script
        -h,--help,   Help    Prints this message
"@


# main method
Function MPWSHEMain($arrgs, $help){
    $opt = [ordered]@{
        script = $null;
        file = $null;
    };

    for($i = 0; $i -lt $arrgs.Length + 1; $i++){
        $arg = $arrgs[$i];
        switch($arg){
            { ($_ -eq "-h") -or ($_ -eq "--help") } {
                Write-Host "$help" -ForegroundColor Green;
                exit 0;
            }

            { ($_ -eq "-f") -or ($_ -eq "--file") } {
                $c = $_
                try{
                    $opt["file"] = $arrgs[$i + 1];
                    if($null -eq $opt["file"]){
                        throw "file name is missing"
                    }
                }
                catch{
                    Write-Host -ForegroundColor red "Missing File to read at $c";
                    exit 1;
                }
            }

            { ($_ -eq "-s") -or ($_ -eq "--script") } {
                $c = $_
                try{
                    $opt["script"] = $arrgs[$i + 1];
                    if($null -eq $opt["script"]){
                        throw "script file name is missing"
                    }
                }
                catch{
                    Write-Host -ForegroundColor red "Missing Script File at $c";
                    exit 1;
                }
            }
        }
    }

    # CheckModule -moduleName "MXPSQL.TextPager" -install $true;
    
    try{
        Import-Module PSReadLine
    }
    catch{

    }

    $Text = New-Object System.Collections.Generic.List[System.Object];
    $File = "";

    Write-Host "MPWSHE Line Editor";
    Write-Host "MXPSQL's Line editor in Powershell";

    $run = $true;
    $line = $null;
    
    if($null -ne $opt["script"]){
        Write-Host "Reading from script";
        $line = 0;
    }
    else{
        Write-Host "Entering REPL";
    }

    if($null -ne $opt["file"]){
        $FStr = "";

        try{
            $FStr = Get-Content -Path $opt["file"] -ErrorAction Stop;
            $File = $opt["file"];
            $Text = New-Object System.Collections.Generic.List[System.Object];
            if($FStr.Length -gt 0){
                $Text.AddRange($FStr.Split("`n"));
            }
        }
        catch{
            Write-Host -ForegroundColor red "file not found";
            exit 1;
        }
    }

    while($run){
        $cmd = "";

        if($null -ne $opt["script"]){
            $cmd = (Get-Content $opt["script"])[$line];

            $line++;

            if($line -ge (Get-Content $opt["script"]).Length){
                $run = $false;
            }
        }
        else{
            $cmd = Read-Host -Prompt "#>";
        }

        if($null -ne $cmd){
            $cmdarg = $cmd.Split(" ");
        }
        else{
            $run = $false;
        }


        if($cmdarg.Length -lt 0){
            continue;
        }
        else{
            $fcmd = $cmdarg[0];

            switch($fcmd){
                # comfort commands
                {($_ -eq "clear") -or ($_ -eq "cls")} {Clear-Host; Break;}
                
                {($_ -eq "exit") -or ($_ -eq "q") -or ($_ -eq "quit")} {$run = $false; Break;}
                
                {($_ -eq "shell") -or ($_ -eq "sh")} {
                    $Command = "";

                    for($i = 1; $i -lt $cmdarg.Length; $i++){
                        $Command += $cmdarg[$i] + " ";
                    }

                    if($Command -ne ""){ 
                        Invoke-Expression $Command;
                    }

                    Break;
                }






                # editing commands
                {($_ -eq "insertEnd") -or ($_ -eq "ie") -or $($_ -eq "appendLine") -or $($_ -eq "append")} {
                    if($cmdarg.Length -lt 3){
                        Write-Host -ForegroundColor yellow "insertEnd: missing argument";
                        Break;
                    }

                    $line = $cmdarg[1] - 1;

                    $Str = "";

                    for($i = 2; $i -lt $cmdarg.Length; $i++){
                        $Str += $cmdarg[$i] + " ";
                    }

                    $Text[$line] = $Text[$line] + $Str;

                    Break;
                }
                {($_ -eq "insert") -or ($_ -eq "i")} {
                    if($cmdarg.Length -lt 3){
                        Write-Host -ForegroundColor yellow "insert: missing argument";
                        Break;
                    }

                    $line = $cmdarg[1] - 1;

                    $Str = "";

                    for($i = 2; $i -lt $cmdarg.Length; $i++){
                        $Str += $cmdarg[$i] + " ";
                    }

                    $Text.Insert($cmdarg[1], $Str);
                    Break;
                }
                {($_ -eq "textAppend") -or ($_ -eq "ta") -or ($_ -eq "a")} {
                    $Str = "";

                    for($i = 1; $i -lt $cmdarg.Length; $i++){
                        $Str += $cmdarg[$i] + " ";
                    }

                    $Text.Add($Str);
                    Break;
                }
                {($_ -eq "edit") -or ($_ -eq "e")} {
                    if($cmdarg.Length -lt 3){
                        Write-Host -ForegroundColor yellow "edit: missing argument";
                        Break;
                    }

                    $line = $cmdarg[1] - 1;
                    $str = "";

                    for($i = 2; $i -lt $cmdarg.Length; $i++){
                        $str = $str + $cmdarg[$i] + " ";
                    }

                    $Text[$line] = $str;
                    Break;
                }
                {($_ -eq "delete") -or ($_ -eq "d") -or ($_ -eq "del")} {
                    if($cmdarg.Length -lt 2){
                        Write-Host -ForegroundColor yellow "delete: missing argument";
                        Break;
                    }

                    $line = $cmdarg[1] - 1;
                    $Text.RemoveAt($line);

                    Break;
                }


                # text io commands
                {(($_ -eq "print") -or ($_ -eq "p")) -or (($_ -eq "v") -or ($_ -eq "view"))} {
                    $Str = [system.String]::Join("`n", $Text.ToArray());

                    if($null -eq $opt["script"]){
                        pager $Str 10;
                    }
                    Break;
                }
                {($_ -eq "write") -or ($_ -eq "w") -or ($_ -eq "Save") -or ($_ -eq "S")} {
                    $Str = [system.String]::Join("`n", $Text.ToArray());
                    if($cmdarg.Length -lt 2){
                        Out-File -FilePath $File -InputObject "$Str";
                    }
                    else{
                        # $Str = [system.String]::Join("`n", $Text.ToArray());
                        $File = $cmdarg[1];
                        Out-File -FilePath $cmdarg[1] -InputObject "$Str";
                    }
                }
                {($_ -eq "read") -or ($_ -eq "r")} {
                    if($cmdarg.Length -lt 2){
                        Write-Host -ForegroundColor yellow "read: missing argument";
                        Break;
                    }

                    $FStr = "";

                    try{
                        $FStr = Get-Content -Path $cmdarg[1] -ErrorAction Stop;
                        $Text = New-Object System.Collections.Generic.List[System.Object];
                        $Text.AddRange($FStr.Split("`n"));
                    }
                    catch{
                        Write-Host -ForegroundColor red "read: file not found";
                        Break;
                    }
                }
                {($_ -eq "nr") -or ($_ -eq "NetwokRead")} {
                    if($cmdarg.Length -lt 2){
                        Write-Host -ForegroundColor yellow "nr: missing argument";
                        Break;
                    }

                    $FStr = "";
                    $IWRO = "";

                    try{
                        $IWRO = Invoke-WebRequest -Uri $cmdarg[1] -ErrorAction Stop;
                        $FStr = $IWRO.Content;;
                        $Text = New-Object System.Collections.Generic.List[System.Object];
                        $Text.AddRange($FStr.Split("`n"));
                    }
                    catch{
                        Write-Host -ForegroundColor red "NetworkRead: url error";
                        Break;
                    }
                }

                # nothing
                {$fcmd.StartsWith("#")} {Break;}
                "" {Break;}
                default{Write-Host -ForegroundColor yellow -BackgroundColor red "Wut you stupid hot soup? That command does not exist!"; Write-Host "It is at this: $($cmd)"; Break;}
            }
        }

        if($null -eq $opt["script"]){
            Write-Host;
        }
    }
}

MPWSHEMain $args $helpStr;

exit 0;