$libPath = "C:\Users\jnno\Downloads\libwebp-1.2.2-windows-x64\bin\cwebp.exe"
$folder = "\\wsl.localhost\Ubuntu\home\jnno\janusznowak.github.io"
$folder ="\\wsl.localhost\Ubuntu\home\jnno\janusznowak.github.ioOldv2\wp-content\uploads\2020\03"
$files = get-childitem $folder -recurse -force -include *.jpg

$files|Out-GridView
foreach ($inputFile in $files) {

   #Call cwebp
   $inputFilePath = $inputFile.FullName
   $outputFilePath = Split-Path -Path $inputFile.FullName
   $outputFilePath = $outputFilePath + "\" + [System.IO.Path]::GetFileNameWithoutExtension($inputFilePath) + ".webp"

   $args = "-q 80 " + $inputFilePath + " -o " + $outputFilePath

   Start-Process -FilePath $libPath -ArgumentList $args -Wait

   $originalFileSize = (Get-Item $inputFilePath).length
   $optimizedFileSize = (Get-Item $outputFilePath).length


   #Prepare output
   $savedBytes = $originalFileSize - $optimizedFileSize
   $savedPercentage = [math]::Round(100 - ($optimizedFileSize / $originalFileSize) * 100)
   $message = $inputFilePath + " " + $outputFilePath + " " + $savedBytes + "bytes " + $savedPercentage + "%"
   Write-Output $message
}
