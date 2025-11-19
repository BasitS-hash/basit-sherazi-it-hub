# Windows System Setup Script
Write-Host "Starting IT Starter Project Setup..." -ForegroundColor Green

Write-Host "This script will help set up a new Windows system for IT operations"

# Basic system checks
Write-Host "Checking system information..."
systeminfo | Select-String "OS Name","OS Version","Total Physical Memory"

Write-Host "Setup checklist completed!" -ForegroundColor Green
Write-Host "Next: Customize this script for your specific needs" -ForegroundColor Yellow