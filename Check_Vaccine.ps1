$state_map = @()
$district_map = @{}

$headers = @{
    'accept' = 'application/json, text/plain, */*'
}

#Get list of all state names
$state_list = Invoke-RestMethod "https://cdn-api.co-vin.in/api/v2/admin/location/states" -Method GET -Headers $headers

 foreach ($state in $state_list.states ) {
    $state_name=$state.state_name
    $state_id=$state.state_id
    #Get list of all districts in each state
    $dis_list = Invoke-RestMethod "https://cdn-api.co-vin.in/api/v2/admin/location/districts/$state_id" -Method GET -Headers $headers
    #Parse each district info
    foreach($district in $dis_list.districts){
        $district_name=$district.district_name
        $district_id=$district.district_id
        $new_dis=@{$district_name=$district_id}
        $district_map.$state_name +=$new_dis

        $Object = New-Object PSObject
        $Object | add-member Noteproperty Name  $state_name
        $Object | add-member Noteproperty District $district_name
        $Object | add-member Noteproperty ID $district_id
        $state_map += $Object
    }  

 }

$GridArguments = @{
    OutputMode = 'Single'
    Title      = 'Please select a District and click OK'
}

$loc_id=""
while([string]::IsNullOrEmpty($loc_id)){
    "Please select a District to continue further "
    $loc_id = $state_map | Select NAME,District| sort NAME,District|Out-GridView @GridArguments | foreach {
        $state_name=$_.NAME
        $district_name=$_.District
        $district_map.$state_name.$district_name
    }
}


for(;;) {

    echo " "
    $now=Get-Date    
    "[ $now ] :: Enquiring centers in $district_name - $state_name "
    echo " "
    $stock=0
    $center_map=@{}
    for($i=0;$i -lt 3;$i++) {
            
        #calculate date
        $dt = (Get-Date).adddays($i*7).ToString("dd-MM-yyyy")
        # Format API with the above calculated date . 
        $uri = "https://cdn-api.co-vin.in/api/v2/appointment/sessions/public/calendarByDistrict?district_id=$loc_id&date=$dt"
        #Hit Gov API
        $center_list = Invoke-RestMethod -URI $uri -Method GET -Headers $headers

        #Parse Json response .
        foreach ($center in $center_list.centers ) {
            #maintain center info
            $center_map[$center.name]=$center.center_id
            foreach($session in $center.sessions ) {
                #Falg if there are any availability
                if($session.available_capacity -gt 0) {
                    #Print details of the center with stock
                    Write-Host -NoNewline NAME - $center.name :: Type - $session.vaccine :: Date - $session.date :: Age limit - $session.min_age_limit :: Available - $session.available_capacity
                    echo " "
                    $stock=1;
                    
                }
            }
        }
    }

    if($stock){
        #Alert the user with Beep sound if there are any stock .
        [console]::beep(2000,5000)        
    }else{ 
       "No stock available at all " + $center_map.count + " centers in $district_name - $state_name" 
    }
    echo " "
    "Pausing for [20 Minutes]"
    #Pause the next iteration until 20 mins.
    Start-Sleep 1200

}
