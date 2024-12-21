# Start logging the actions 
Start-Transcript -Path C:\Temp\resize-system-disk.log -Append -Force

# Get OS Disk
$disk = get-disk | where-object {$_.IsBoot -eq "true" -and $_.IsSystem -eq "true"}
    
# Get the drive letter assigned to the disk partition where OS is installed
$driveLetter = (Get-Partition -DiskNumber $disk.Number | Where-Object {$_.DriveLetter}).DriveLetter

# Get current size of the OS parition on the Disk
$currentOSDiskSize = (Get-Partition -DriveLetter $driveLetter).Size        

# Get Partition Number of the OS partition on the Disk
$partitionNum = (Get-Partition -DriveLetter $driveLetter).PartitionNumber

# Get the max allowed size for the OS Partition on the disk
$allowedSize = (Get-PartitionSupportedSize -DiskNumber $disk.Number -PartitionNumber $partitionNum).SizeMax
    
if ($currentOSDiskSize -lt $allowedSize)
{
  $totalDiskSize = $allowedSize
    
  # Resize the OS Partition to Include the entire Unallocated disk space
  $resizeOp = Resize-Partition -DriveLetter C -Size $totalDiskSize
  Write-Host "OS Drive Resize Completed $resizeOp"
}
else 
  {
  Write-Host "There is no Unallocated space to extend OS Drive Partition size"
  }
Stop-Transcript
# Start logging the actions 
Start-Transcript -Path C:\Temp\Init-DataDisks.log -Append -Force

# Move CD-ROM drive to Z:
Write-Host "Moving CD-ROM drive to Z:.."
Get-WmiObject -Class Win32_volume -Filter 'DriveType=5' | Select-Object -First 1 | Set-WmiInstance -Arguments @{DriveLetter='Z:'}

# Set the parameters 
$disks = Get-Disk | Where-Object partitionstyle -eq 'raw' | Sort-Object number
$letters = 69..89 | ForEach-Object { [char]$_ }
$count = 0
$label = "Data"

Write-Host "Formatting disks.."
foreach ($disk in $disks) {
  $driveLetter = $letters[$count].ToString()
  $disk |
  Initialize-Disk -PartitionStyle MBR -PassThru |
  New-Partition -UseMaximumSize -DriveLetter $driveLetter |
  Format-Volume -FileSystem NTFS -NewFileSystemLabel "$label.$count" -Confirm:$false -Force
  Write-Host "$label.$count"
  $count++
}
Stop-Transcript
