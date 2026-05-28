# Batch deployment system for instant multi-customer setup
# Deploy multiple customers simultaneously with collision prevention

param(
    [Parameter(Mandatory=$true)]
    [string[]]$CustomerNames,
    
    [Parameter(Mandatory=$false)]
    [switch]$BusinessSkills,
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoPort,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipValidation,
    
    [Parameter(Mandatory=$false)]
    [switch]$Parallel
)

class BatchDeploymentResult {
    [string]$CustomerName
    [bool]$Success
    [int]$Port
    [string]$Message
    [timespan]$DeploymentTime
    [string]$DashboardUrl
    
    BatchDeploymentResult([string]$CustomerName, [bool]$Success, [int]$Port, [string]$Message, [timespan]$DeploymentTime) {
        $this.CustomerName = $CustomerName
        $this.Success = $Success
        $this.Port = $Port
        $this.Message = $Message
        $this.DeploymentTime = $DeploymentTime
        $this.DashboardUrl = if ($Success) { "http://localhost:$Port" } else { "N/A" }
    }
}

function Get-BatchAvailablePorts {
    param([int]$Count)
    
    $startPort = 9120
    $endPort = 9199
    
    $usedPorts = Get-NetTCPConnection -ErrorAction SilentlyContinue | 
                Where-Object { $_.LocalAddress -eq "0.0.0.0" -or $_.LocalAddress -eq "127.0.0.1" } | 
                Select-Object -ExpandProperty LocalPort | 
                Sort-Object -Unique
    
    $availablePorts = @()
    for ($port = $startPort; $port -le $endPort; $port++) {
        if ($port -notin $usedPorts) {
            $availablePorts += $port
            if ($availablePorts.Count -eq $Count) {
                break
            }
        }
    }
    
    return $availablePorts
}

function Invoke-SingleDeployment {
    param(
        [string]$CustomerName,
        [int]$Port,
        [switch]$BusinessSkills,
        [switch]$SkipValidation
    )
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        # Use rapid-deploy for individual deployment
        $deployArgs = @{
            CustomerName = $CustomerName
            Port = $Port
            BusinessSkills = $BusinessSkills
            SkipValidation = $SkipValidation
        }
        
        $null = & ".\rapid-deploy.ps1" @deployArgs 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            $stopwatch.Stop()
            return [BatchDeploymentResult]::new(
                $CustomerName,
                $true,
                $Port,
                "Deployed successfully",
                $stopwatch.Elapsed
            )
        } else {
            $stopwatch.Stop()
            return [BatchDeploymentResult]::new(
                $CustomerName,
                $false,
                $Port,
                "Deployment failed",
                $stopwatch.Elapsed
            )
        }
        
    } catch {
        $stopwatch.Stop()
        return [BatchDeploymentResult]::new(
            $CustomerName,
            $false,
            $Port,
            "Error: $($_.Exception.Message)",
            $stopwatch.Elapsed
        )
    }
}

function Show-BatchResults {
    param([BatchDeploymentResult[]]$Results)
    
    Write-Host "`n" + "=" * 60 -ForegroundColor Gray
    Write-Host "📊 BATCH DEPLOYMENT RESULTS" -ForegroundColor Magenta
    Write-Host "=" * 60 -ForegroundColor Gray
    
    $successful = $Results | Where-Object { $_.Success }
    $failed = $Results | Where-Object { -not $_.Success }
    
    Write-Host "`n✅ Successful Deployments: $($successful.Count)/$($Results.Count)" -ForegroundColor Green
    if ($successful.Count -gt 0) {
        foreach ($result in $successful) {
            Write-Host "   🏢 $($result.CustomerName): Port $($result.Port) ($($result.DeploymentTime.TotalSeconds.ToString('F1'))s)" -ForegroundColor White
            Write-Host "      🌐 $($result.DashboardUrl)" -ForegroundColor Cyan
        }
    }
    
    if ($failed.Count -gt 0) {
        Write-Host "`n❌ Failed Deployments: $($failed.Count)" -ForegroundColor Red
        foreach ($result in $failed) {
            Write-Host "   🏢 $($result.CustomerName): $($result.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host "`n📋 Management Commands:" -ForegroundColor White
    foreach ($result in $successful) {
        Write-Host "   Stop $($result.CustomerName): .\customer-manager.ps1 -Action Stop -CustomerName '$($result.CustomerName)'" -ForegroundColor Gray
    }
    
    return $successful.Count -eq $Results.Count
}

# Main execution
$batchStartTime = Get-Date

Write-Host "🚀 BATCH DEPLOYMENT SYSTEM" -ForegroundColor Magenta
Write-Host "Deploying $($CustomerNames.Count) customers simultaneously..." -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray

# Validate customer names
foreach ($name in $CustomerNames) {
    if ($name -match '[^a-zA-Z0-9\-_]') {
        Write-Host "❌ Invalid customer name: $name (use letters, numbers, hyphens, underscores only)" -ForegroundColor Red
        exit 1
    }
}

# Allocate ports
$availablePorts = Get-BatchAvailablePorts -Count $CustomerNames.Count
if ($availablePorts.Count -lt $CustomerNames.Count) {
    Write-Host "❌ Not enough available ports. Need $($CustomerNames.Count), have $($availablePorts.Count)" -ForegroundColor Red
    exit 1
}

Write-Host "🔢 Allocated ports: $($availablePorts -join ', ')" -ForegroundColor Cyan

# Prepare deployments
$deployments = @()
for ($i = 0; $i -lt $CustomerNames.Count; $i++) {
    $deployments += @{
        CustomerName = $CustomerNames[$i]
        Port = $availablePorts[$i]
    }
}

# Execute deployments
$results = @()

if ($Parallel) {
    Write-Host "⚡ Starting parallel deployments..." -ForegroundColor Yellow
    
    # Create jobs for parallel execution
    $jobs = @()
    foreach ($deployment in $deployments) {
        $job = Start-Job -ScriptBlock {
            param($CustomerName, $Port, $BusinessSkills, $SkipValidation, $WorkingDir)
            
            Set-Location $WorkingDir
            $null = & ".\rapid-deploy.ps1" -CustomerName $CustomerName -Port $Port -BusinessSkills:$BusinessSkills -SkipValidation:$SkipValidation
            
            return @{
                CustomerName = $CustomerName
                Success = ($LASTEXITCODE -eq 0)
                Port = $Port
                Message = if ($LASTEXITCODE -eq 0) { "Deployed successfully" } else { "Deployment failed" }
                ExitCode = $LASTEXITCODE
            }
        } -ArgumentObject $deployment.CustomerName, $deployment.Port, $BusinessSkills, $SkipValidation, (Get-Location)
        
        $jobs += $job
    }
    
    # Wait for all jobs and collect results
    foreach ($job in $jobs) {
        $jobResult = Receive-Job -Job $job -Wait
        Remove-Job -Job $job
        
        $results += [BatchDeploymentResult]::new(
            $jobResult.CustomerName,
            $jobResult.Success,
            $jobResult.Port,
            $jobResult.Message,
            [timespan]::FromSeconds(0) # Time not tracked in parallel mode
        )
    }
    
} else {
    Write-Host "🔄 Starting sequential deployments..." -ForegroundColor Yellow
    
    foreach ($deployment in $deployments) {
        Write-Host "`n🏢 Deploying: $($deployment.CustomerName)..." -ForegroundColor Cyan
        
        $result = Invoke-SingleDeployment -CustomerName $deployment.CustomerName -Port $deployment.Port -BusinessSkills:$BusinessSkills -SkipValidation:$SkipValidation
        $results += $result
        
        if ($result.Success) {
            Write-Host "✅ $($deployment.CustomerName) deployed successfully" -ForegroundColor Green
        } else {
            Write-Host "❌ $($deployment.CustomerName) deployment failed: $($result.Message)" -ForegroundColor Red
        }
    }
}

# Show final results
$allSuccessful = Show-BatchResults -Results $results

$totalTime = (Get-Date) - $batchStartTime
Write-Host "`n⏱️  Total Batch Time: $($totalTime.TotalSeconds.ToString('F2'))s" -ForegroundColor Magenta

if ($allSuccessful) {
    Write-Host "🎉 All customers deployed successfully!" -ForegroundColor Green
} else {
    Write-Host "⚠️  Some deployments failed. Check individual results above." -ForegroundColor Yellow
}

exit ([int](-not $allSuccessful))
