################################################################################
#                                                                              #
#                             Reddit Downloader                                #
#                   Written By: MSgt Anthony V. Brechtel                       #
#                                                                              #
################################################################################
clear-host
$script:memBefore = (Get-Process -id $pid).WS
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
Set-Location $dir
################################################################################
######Load Assemblies###########################################################
Add-Type -AssemblyName 'System.Windows.Forms'
Add-Type -AssemblyName 'System.Drawing'
Add-Type -AssemblyName 'PresentationFramework'
[System.Windows.Forms.Application]::EnableVisualStyles();

################################################################################
######Load Console Scaling Support##############################################
# Dummy WPF window (prevents auto scaling).
[xml]$Xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    x:Name="Window">
</Window>
"@
$Reader = (New-Object System.Xml.XmlNodeReader $Xaml)
$Window = [Windows.Markup.XamlReader]::Load($Reader)
################################################################################
######Global Variables##########################################################

$script:program_title = "Reddit Downloader"
$script:version = "3.5"
$script:site_list = new-object System.Collections.Hashtable
$settings = @{};
$script:list_box_select_status = 1;
$script:list_box_lock = 0;
$script:cycler_job = "";


###Idle Timer
if(Test-Path variable:Script:Timer){$Script:Timer.Dispose();}
$Script:Timer = New-Object System.Windows.Forms.Timer                #Main system timer, most functions load through this timer
$Script:Timer.Interval = 50
$Script:CountDown = 1 
if(Test-Path variable:Script:Form){Remove-Variable Form}

#################################################################################
#####Main########################################################################
function main
{
    ##################################################################################
    ###########Main Form
    $first = 0;
    if(!(Test-Path variable:Script:Form))
    {
        $first = 1;
        $script:Form = New-Object System.Windows.Forms.Form
        $script:Form.Location = "200, 200"
        $script:Form.Font = "Copperplate Gothic,8.1"
        $script:Form.ForeColor = "Black"
        $script:Form.BackColor = "#434343"
        $script:Form.Text = "  Reddit Downloader"
        $script:Form.Width = 1300 #1245
        $script:Form.Height = 900
        #$script:Form.ClientSize = "530,450"
    }


    ##################################################################################
    ###########Title Main
    $y_pos = 15
    $title1            = New-Object System.Windows.Forms.Label   
    $title1.Font       = New-Object System.Drawing.Font("Copperplate Gothic Bold",21,[System.Drawing.FontStyle]::Regular)
    $title1.Text       = $script:program_title
    $title1.TextAlign  = "MiddleCenter"
    $title1.ForeColor  = "white"
    $title1.Size       =  New-Object System.Drawing.Size($script:Form.Width,45)
    $title1.Location   = New-Object System.Drawing.Size((($script:Form.width / 2) - ($script:Form.width / 2)),$y_pos)
    $script:Form.Controls.Add($title1)

    ##################################################################################
    ###########Title Written By
    $y_pos = $y_pos + 35
    $title2            = New-Object System.Windows.Forms.Label
    $title2.Font       = New-Object System.Drawing.Font("Copperplate Gothic",7.5,[System.Drawing.FontStyle]::Regular)
    $title2.Text       = "Ver $script:version"
    $title2.TextAlign  = "MiddleCenter"
    $title2.ForeColor  = "darkgray"
    $title2.Size       =  New-Object System.Drawing.Size($script:Form.Width,35)
    $title2.Location   = New-Object System.Drawing.Size((($script:Form.width / 2) - ($script:Form.width / 2)),$y_pos)
    $script:Form.Controls.Add($title2)

    ###########List Box
    $y_pos = $y_pos + 40
    $script:reddit_list_box = New-Object -TypeName System.Windows.Forms.CheckedListBox
    $script:reddit_list_box.Location = New-Object System.Drawing.Size(20,$y_pos)
    $script:reddit_list_box.Size = New-Object System.Drawing.Size((($script:Form.Width / 3) *2),(($script:Form.height - ($y_pos + 140))))
    $script:reddit_list_box.Font = New-Object System.Drawing.Font("Lucida Console",12,[System.Drawing.FontStyle]::Regular)

    [void] $script:reddit_list_box.Items.add("Select All")
    $script:reddit_list_box.SetItemChecked($script:reddit_list_box.Items.IndexOf("Select All"), $true);
    if($script:site_list.count -ne 0)
    {
        foreach($reddit in $script:site_list.getEnumerator() | sort key)
        {
            $site = $reddit.key
            $entry_array = csv_line_to_array $reddit.value
            [void] $script:reddit_list_box.Items.add("$site")
            if($entry_array[0] -eq "True")
            {
                if($script:site_list.contains("$site")) #Check the items that the user had checked last
                {
                    $script:reddit_list_box.SetItemChecked($script:reddit_list_box.Items.IndexOf("$site"), $true);
                }
                ##Update Select Item
                if($script:list_box_select_status -eq 1)
                {
                    $script:reddit_list_box.SetItemChecked($script:reddit_list_box.Items.IndexOf("Select All"),$true);
                    $script:reddit_list_box.items[$script:reddit_list_box.Items.IndexOf("Select All")] = "Select None"
                    $script:list_box_select_status = 0;
                }
            }
            else
            {
                
                if($script:site_list.contains("$site")) #Check the items that the user had checked last
                {
                    $script:reddit_list_box.SetItemChecked($script:reddit_list_box.Items.IndexOf("$site"), $false);
                }
            }  
        }
    }
    $script:reddit_list_box.Add_ItemCheck({
        if(($this.text) -and (!($this.text -match "^Select")))
        {
            $reddit = $this.text
            $entry_array = csv_line_to_array $script:site_list[$reddit]     
            if($entry_array[0] -eq "True")
            {
                $entry_array[0] = "False"
            }
            else
            {
                $entry_array[0] = "True"
            }
            $line = "";
            $line = csv_write_line $line $entry_array[0]
            $line = csv_write_line $line $entry_array[1]
            $line = csv_write_line $line $entry_array[2]
            $line = csv_write_line $line $entry_array[3]
            $line = csv_write_line $line $entry_array[4]
            $line = csv_write_line $line $entry_array[5]
            $script:site_list[$reddit] = $line
            update_reddits
        }
    })
    $script:reddit_list_box.Add_SelectedValueChanged({
        if((!($this.text -match "^Select")) -and ($this.text -ne ""))
        {
            update_side_info($this.text)
        }
        elseif(($this.text -match "Select All") -and ($script:list_box_lock -ne 1))
        {
            $script:list_box_lock = 1;
                    $script:reddit_list_box.SetItemChecked($script:reddit_list_box.Items.IndexOf("Select All"),$true);
                    $script:reddit_list_box.items[$script:reddit_list_box.Items.IndexOf("Select All")] = "Select None"
                    $script:list_box_select_status = 0;
                    foreach($item in $($script:site_list.keys))
                    {
                        $line = $script:site_list[$item] -replace "^False","True"
                        $script:site_list[$item] = $line
                    }
            update_reddits
            $script:list_box_lock = 0;
        }
        elseif(($this.text -match "Select None") -and ($script:list_box_lock -ne 1))
        {
            $script:list_box_lock = 1;
                    $script:reddit_list_box.SetItemChecked($script:reddit_list_box.Items.IndexOf("Select None"),$false);
                    $script:reddit_list_box.items[$script:reddit_list_box.Items.IndexOf("Select None")] = "Select All"
                    $script:list_box_select_status = 0;
                    foreach($item in $($script:site_list.keys))
                    {
                        $line = $script:site_list[$item] -replace "^True","False"
                        $script:site_list[$item] = $line
                    }
            update_reddits
            $script:list_box_lock = 0;
        }

    })
    




    $script:Form.Controls.Add($script:reddit_list_box)
    ##################################################################################
    ###########Add Reddit Button
    $y_pos = $y_pos
    $button_Add_Reddit = New-Object System.Windows.Forms.Button
    $button_Add_Reddit.Location = New-Object System.Drawing.Size(($script:reddit_list_box.location.x + $script:reddit_list_box.width + 10), $y_pos)
    $button_Add_Reddit.Size = New-Object System.Drawing.Size((($script:Form.width / 3) - 65), 30)
    $button_Add_Reddit.ForeColor = "White"
    $button_Add_Reddit.Backcolor = "#606060"
    $button_Add_Reddit.Text = "Add Subreddit"
    $button_Add_Reddit.add_Click({
        
        add_subreddit_form "Add"
    
    })
    $script:Form.Controls.Add($button_Add_Reddit)

    ##################################################################################
    ###########Edit Reddit Button
    $y_pos = $y_pos + 35
    $button_Edit_Reddit = New-Object System.Windows.Forms.Button
    $button_Edit_Reddit.Location = New-Object System.Drawing.Size($button_Add_Reddit.location.x, $y_pos)
    $button_Edit_Reddit.Size = New-Object System.Drawing.Size($button_Add_Reddit.width, 30)
    $button_Edit_Reddit.ForeColor = "White"
    $button_Edit_Reddit.Backcolor = "#606060"
    $button_Edit_Reddit.Text = "Edit Subreddit"
    $button_Edit_Reddit.Add_Click({
        $entry = $script:reddit_list_box.SelectedItem
        if($entry -match "r/|u/")
        {
            add_subreddit_form "Edit" "$entry"
        } 
    })
    $script:Form.Controls.Add($button_Edit_Reddit)


    ##################################################################################
    ###########Remove Reddit Button
    $y_pos = $y_pos + 35
    $button_Remove_Reddit = New-Object System.Windows.Forms.Button
    $button_Remove_Reddit.Location = New-Object System.Drawing.Size($button_Add_Reddit.location.x, $y_pos)
    $button_Remove_Reddit.Size = New-Object System.Drawing.Size($button_Add_Reddit.width, 30)
    $button_Remove_Reddit.ForeColor = "White"
    $button_Remove_Reddit.Backcolor = "#606060"
    $button_Remove_Reddit.Text = "Remove Subreddit"
    $button_Remove_Reddit.add_Click({
        $entry = $script:reddit_list_box.SelectedItem
        if($entry -match "r/|u/")
        {
            $message = "Are you sure you want to delete $entry ?`n`n"
            $yesno = [System.Windows.Forms.MessageBox]::Show("$message","Delete $entry ?", "YesNo" , "Information" , "Button1")
            if($yesno -eq "Yes")
            {
                $script:site_list.Remove($entry);
                update_reddits
            }
        }
    })
    $script:Form.Controls.Add($button_Remove_Reddit)

    ##################################################################################
    ###########Separator Bar 1
    $y_pos = (($script:Form.height / 3))
    $separator_bar1                             = New-Object system.Windows.Forms.Label
    $separator_bar1.text                        = ""
    $separator_bar1.AutoSize                    = $false
    $separator_bar1.BorderStyle                 = "fixed3d"
    #$separator_bar1.ForeColor                   = $script:settings['DIALOG_BOX_TEXT_BOLD_COLOR']
    $separator_bar1.Anchor                      = 'top,left'
    $separator_bar1.width                       = $button_Add_Reddit.width
    $separator_bar1.height                      = 1
    $separator_bar1.location                    = New-Object System.Drawing.Point($button_Add_Reddit.location.x,$y_pos)
    $separator_bar1.TextAlign                   = 'MiddleLeft'
    $script:Form.controls.Add($separator_bar1);

    

    ##################################################################################
    ###########Subreddit Title
    $y_pos = $y_pos + 3;
    $reddit_title            = New-Object System.Windows.Forms.Label   
    $reddit_title.Font       = New-Object System.Drawing.Font("Copperplate Gothic Bold",9,[System.Drawing.FontStyle]::Regular)
    $reddit_title.Text       = ""
    $reddit_title.TextAlign  = "MiddleCenter"
    $reddit_title.Width      = $button_Add_Reddit.width
    $reddit_title.height     = 35
    $reddit_title.ForeColor  = "white"
    $reddit_title.Location   = New-Object System.Drawing.Point($button_Add_Reddit.location.x,$y_pos)
    $script:Form.Controls.Add($reddit_title)


    $y_pos = $y_pos + 30;
    $images_label            = New-Object System.Windows.Forms.Label   
    $images_label.Font       = New-Object System.Drawing.Font("Copperplate Gothic Bold",7,[System.Drawing.FontStyle]::Regular)
    $images_label.Text       = "Images:"
    $images_label.TextAlign  = "MiddleRight"
    $images_label.Width      = 80
    $images_label.height     = 30
    $images_label.ForeColor  = "white"
    $images_label.Location   = New-Object System.Drawing.Point($button_Add_Reddit.location.x,$y_pos)
    $script:Form.Controls.Add($images_label)

    $images_value                = New-Object System.Windows.Forms.Label  
    $images_value.Font           = New-Object System.Drawing.Font("Copperplate Gothic",7,[System.Drawing.FontStyle]::Regular)
    $images_value.Text           = "N/A"
    $images_value.TextAlign      = "MiddleLeft"
    $images_value.Width          = ($button_Add_Reddit.width - 80)
    $images_value.height         = 20
    $images_value.accessiblename = ""
    $images_value.ForeColor      = "white"
    $images_value.Location       = New-Object System.Drawing.Point(($images_label.location.x + $images_label.Width + 2),$y_pos)
    $script:Form.Controls.Add($images_value)


    $y_pos = $y_pos + 30;
    $videos_label            = New-Object System.Windows.Forms.Label   
    $videos_label.Font       = New-Object System.Drawing.Font("Copperplate Gothic Bold",7,[System.Drawing.FontStyle]::Regular)
    $videos_label.Text       = "Videos:"
    $videos_label.TextAlign  = "MiddleRight"
    $videos_label.Width      = 80
    $videos_label.height     = 30
    $videos_label.ForeColor  = "white"
    $videos_label.Location   = New-Object System.Drawing.Point($button_Add_Reddit.location.x,$y_pos)
    $script:Form.Controls.Add($videos_label)

    $videos_value                = New-Object System.Windows.Forms.Label  
    $videos_value.Font           = New-Object System.Drawing.Font("Copperplate Gothic",7,[System.Drawing.FontStyle]::Regular)
    $videos_value.Text           = "N/A"
    $videos_value.TextAlign      = "MiddleLeft"
    $videos_value.Width          = ($button_Add_Reddit.width - 80)
    $videos_value.height         = 30
    $videos_value.accessiblename = ""
    $videos_value.ForeColor      = "white"
    $videos_value.Location       = New-Object System.Drawing.Point(($videos_label.location.x + $videos_label.Width + 2),$y_pos)
    $script:Form.Controls.Add($videos_value)

    $y_pos = $y_pos + 30;
    $width_label            = New-Object System.Windows.Forms.Label   
    $width_label.Font       = New-Object System.Drawing.Font("Copperplate Gothic Bold",7,[System.Drawing.FontStyle]::Regular)
    $width_label.Text       = "Width:"
    $width_label.TextAlign  = "MiddleRight"
    $width_label.Width      = 80
    $width_label.height     = 30
    $width_label.ForeColor  = "white"
    $width_label.Location   = New-Object System.Drawing.Point($button_Add_Reddit.location.x,$y_pos)
    $script:Form.Controls.Add($width_label)

    $width_value                = New-Object System.Windows.Forms.Label  
    $width_value.Font           = New-Object System.Drawing.Font("Copperplate Gothic",7,[System.Drawing.FontStyle]::Regular)
    $width_value.Text           = "N/A"
    $width_value.TextAlign      = "MiddleLeft"
    $width_value.Width          = ($button_Add_Reddit.width - 80)
    $width_value.height         = 30
    $width_value.accessiblename = ""
    $width_value.ForeColor      = "white"
    $width_value.Location       = New-Object System.Drawing.Point(($width_label.location.x + $width_label.Width + 2),$y_pos)
    $script:Form.Controls.Add($width_value)

    $y_pos = $y_pos + 30;
    $height_label            = New-Object System.Windows.Forms.Label   
    $height_label.Font       = New-Object System.Drawing.Font("Copperplate Gothic Bold",7,[System.Drawing.FontStyle]::Regular)
    $height_label.Text       = "Height:"
    $height_label.TextAlign  = "MiddleRight"
    $height_label.Width      = 80
    $height_label.height     = 30
    $height_label.ForeColor  = "white"
    $height_label.Location   = New-Object System.Drawing.Point($button_Add_Reddit.location.x,$y_pos)
    $script:Form.Controls.Add($height_label)

    $height_value                = New-Object System.Windows.Forms.Label  
    $height_value.Font           = New-Object System.Drawing.Font("Copperplate Gothic",7,[System.Drawing.FontStyle]::Regular)
    $height_value.Text           = "N/A"
    $height_value.TextAlign      = "MiddleLeft"
    $height_value.Width          = ($button_Add_Reddit.width - 80)
    $height_value.height         = 30
    $height_value.accessiblename = ""
    $height_value.ForeColor      = "white"
    $height_value.Location       = New-Object System.Drawing.Point(($height_label.location.x + $height_label.Width + 2),$y_pos)
    $script:Form.Controls.Add($height_value)

    $y_pos = $y_pos + 30;
    $output_label            = New-Object System.Windows.Forms.Label   
    $output_label.Font       = New-Object System.Drawing.Font("Copperplate Gothic Bold",7,[System.Drawing.FontStyle]::Regular)
    $output_label.Text       = "Output:"
    $output_label.TextAlign  = "MiddleRight"
    $output_label.Width      = 80
    $output_label.height     = 30
    $output_label.ForeColor  = "white"
    $output_label.Location   = New-Object System.Drawing.Point($button_Add_Reddit.location.x,$y_pos)
    $script:Form.Controls.Add($output_label)

    $output_value                = New-Object System.Windows.Forms.Label  
    $output_value.Font           = New-Object System.Drawing.Font("Copperplate Gothic",7,[System.Drawing.FontStyle]::Regular)
    $output_value.Text           = "N/A"
    $output_value.TextAlign      = "MiddleLeft"
    $output_value.width          = ($button_Add_Reddit.width - 80)
    $output_value.height         = 30
    $output_value.accessiblename = "N/A"
    $output_value.ForeColor      = "white"
    $output_value.Location       = New-Object System.Drawing.Point(($output_label.location.x + $output_label.width + 2),$y_pos)
    $script:Form.Controls.Add($output_value)

    $y_pos = $y_pos + 35
    $open_output_dir = New-Object System.Windows.Forms.Button
    $open_output_dir.location = New-Object System.Drawing.Point($button_Add_Reddit.location.x,$y_pos)
    $open_output_dir.Size = New-Object System.Drawing.Point($button_Add_Reddit.width, 30)
    $open_output_dir.ForeColor = "White"
    $open_output_dir.Backcolor = "#606060"
    $open_output_dir.Text = "Open Output Dir"
    $open_output_dir.accessiblename = $dir
    $open_output_dir.add_Click({
        
        Invoke-Item -literalpath $this.accessiblename

    })
    $script:Form.Controls.Add($open_output_dir)

    ##################################################################################
    ###########Separator Bar 2
    $y_pos = $y_pos = (($script:Form.height / 3) * 2)
    $separator_bar2                             = New-Object system.Windows.Forms.Label
    $separator_bar2.text                        = ""
    $separator_bar2.AutoSize                    = $false
    $separator_bar2.BorderStyle                 = "fixed3d"
    #$separator_bar2.ForeColor                   = $script:settings['DIALOG_BOX_TEXT_BOLD_COLOR']
    $separator_bar2.Anchor                      = 'top,left'
    $separator_bar2.width                       = $button_Add_Reddit.width
    $separator_bar2.height                      = 1
    $separator_bar2.location                    = New-Object System.Drawing.Point($button_Add_Reddit.location.x,$y_pos)
    $separator_bar2.TextAlign                   = 'MiddleLeft'
    $script:Form.controls.Add($separator_bar2);

    ##################################################################################
    ###########Progress Bar
    $progress_bar = New-Object System.Windows.Forms.ProgressBar
    $progress_bar.Name = 'progressBar1'
    $progress_bar.Value = 0
    $progress_bar.Style="Continuous"
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Width = $script:Form.width - 60
    $System_Drawing_Size.Height = 30
    $progress_bar.Size = $System_Drawing_Size
    $progress_bar.Location = New-Object System.Drawing.Size($script:reddit_list_box.location.x, ($script:reddit_list_box.location.y + $script:reddit_list_box.height + 3));
    $progress_bar.Value = "0"
    $script:Form.Controls.Add($progress_bar)

    ##################################################################################
    ###########Progress Bar Status Label
    $progress_bar_label = New-Object System.Windows.Forms.Label 
    $progress_bar_label.Location = New-Object System.Drawing.Size($progress_bar.location.x, ($progress_bar.location.y + $progress_bar.height + 10));
    $progress_bar_label.width = $progress_bar.width
    $progress_bar_label.height = 23
    $progress_bar_label.TextAlign  = "MiddleCenter"
    $progress_bar_label.ForeColor = "White"
    $progress_bar_label.Text = "Not Running"
    $script:Form.Controls.Add($progress_bar_label)


    ##################################################################################
    ###########Run Interval Label
    $y_pos = $y_pos + 5
    $interval_label            = New-Object System.Windows.Forms.Label   
    $interval_label.Font       = New-Object System.Drawing.Font("Copperplate Gothic Bold",7,[System.Drawing.FontStyle]::Regular)
    $interval_label.Text       = "Run Interval:"
    $interval_label.TextAlign  = "MiddleRight"
    $interval_label.Width      = (($button_Add_Reddit.width / 2))
    $interval_label.height     = 25
    $interval_label.ForeColor  = "white"
    $interval_label.Location   = New-Object System.Drawing.Point($button_Add_Reddit.location.x,$y_pos)
    $script:Form.Controls.Add($interval_label)

    $interval_input                        = New-Object system.Windows.Forms.TextBox                       
    $interval_input.AutoSize                 = $true
    $interval_input.ForeColor                = "Black"
    $interval_input.BackColor                = "White"
    $interval_input.Anchor                   = 'top,left'
    $interval_input.width                    = 80
    $interval_input.height                   = 3
    $interval_input.text                     = $script:settings["SLEEP_TIMER"]
    $interval_input.location                 = New-Object System.Drawing.Point(($interval_label.Location.x + $interval_label.width + 5),$y_pos)
    $interval_input.add_lostfocus({
        if(!($this.text -match '^[0-9]+$'))
        {
            $this.text = $script:settings["SLEEP_TIMER"];
        }
        else
        {
            $script:settings["SLEEP_TIMER"] = $this.text
            update_settings
        }

    })
    $script:Form.controls.Add($interval_input);

    $interval_min_label            = New-Object System.Windows.Forms.Label   
    $interval_min_label.Font       = New-Object System.Drawing.Font("Copperplate Gothic Bold",6,[System.Drawing.FontStyle]::Regular)
    $interval_min_label.Text       = "Mins"
    $interval_min_label.TextAlign  = "bottomLeft"
    $interval_min_label.Width      = 120
    $interval_min_label.height     = 20
    $interval_min_label.ForeColor  = "white"
    $interval_min_label.Location   = New-Object System.Drawing.Point(($interval_input.Location.x + $interval_input.width + 1),$y_pos)
    $script:Form.Controls.Add($interval_min_label)



    ##################################################################################
    ###########Download Reddits Button
    $y_pos = $y_pos + 30
    $download_reddits = New-Object System.Windows.Forms.Button
    $download_reddits.Location = New-Object System.Drawing.Point($button_Add_Reddit.location.x, $y_pos)
    $download_reddits.Size = New-Object System.Drawing.Point($button_Add_Reddit.width, 30)
    $download_reddits.ForeColor = "White"
    $download_reddits.Backcolor = "#606060"
    $download_reddits.Text = "Download Reddits"
    $download_reddits.add_Click({
        if($this.text -eq "Download Reddits")
        {
            $this.Text = "Stop Running..."
            $progress_bar_label.Text = "Thinking..."
            $script:reddit_list_box.enabled = $false
            $button_Add_Reddit.enabled = $false
            $button_Edit_Reddit.enabled = $false
            $button_Remove_Reddit.enabled = $false
            cycler
        }
        else
        {
            Stop-Job -job $script:cycler_job
            Remove-Job -job $script:cycler_job
            $this.Text = "Download Reddits"
            $progress_bar.Value = "0"
            $progress_bar_label.Text = "Not Running"
            $script:reddit_list_box.enabled = $true
            $button_Add_Reddit.enabled = $true
            $button_Edit_Reddit.enabled = $true
            $button_Remove_Reddit.enabled = $true
        }

    })
    $script:Form.Controls.Add($download_reddits)
    ####################################################
    if($script:reddit_list_box.Items.count -ge 2)
    {
        $script:reddit_list_box.SelectedIndex = 1
    }

    #$script:Form.Add_Shown({
    #$message = "WARNING: This software is not to be used to overload, spam, or DDoS Reddit servers. Please use sparingly with high intervals for long periods of use. I am not responsible for the misuse of this software!"
    #[System.Windows.MessageBox]::Show($message,"!!!WARNING!!!",'Ok')
    #});

    if($first -eq 1)
    {
        [void] $script:Form.ShowDialog()  
    }
}
################################################################################
######Update Side Info##########################################################
function update_side_info($reddit)
{        
    $reddit_array = csv_line_to_array $script:site_list[$reddit]
    $status  = $reddit_array[0]
    $output  = $reddit_array[1]
    $height  = $reddit_array[2]
    $width   = $reddit_array[3]
    $images  = $reddit_array[4]
    $videos  = $reddit_array[5]

    $reddit_title.Text = $reddit

    $images = $images -replace "True","Enabled"
    $images = $images -replace "False","Disabled"
    $images_value.Text = $images
    $images_value.accessiblename = $images
    if($images -eq "Enabled")
    {
        $images_value.Forecolor = "Lime"
    }
    else
    {
        $images_value.Forecolor = "Red"
    }

    $videos = $videos -replace "True","Enabled"
    $videos = $videos -replace "False","Disabled"
    $videos_value.Text = $videos
    $videos_value.accessiblename = $videos
    if($videos -eq "Enabled")
    {
        $videos_value.Forecolor = "Lime"
    }
    else
    {
        $videos_value.Forecolor = "Red"
    }
    
    $height_value.Text = $height
    $height_value.accessiblename = $height

    $width_value.Text = $width
    $width_value.accessiblename = $width
    
    $output_shorthand = $reddit -replace "u/|r/","\"
    $output_shorthand = $output + $output_shorthand
    $output_shorthand = $output_shorthand -replace "\\\\","\"


    if(Test-Path -literalpath $output_shorthand)
    {
        $open_output_dir.AccessibleName = $output_shorthand
    }
    elseif(Test-path -LiteralPath $output)
    {
        $open_output_dir.AccessibleName = $output
    }
    else
    {
        $open_output_dir.AccessibleName = $dir
    }

    [int]$offset = ($output_value.width / 8.5)
    if($output_shorthand.length -gt $offset)
    {
        $output_shorthand = "..." + $output_shorthand.substring(($output_shorthand.length - $offset),$offset)
    }

    $output_value.Text = $output_shorthand
    $output_value.accessiblename = $output_shorthand
        
}
################################################################################
######Add Subreddit#############################################################
function add_subreddit_form($mode,$entry)
{
    $add_subreddit_form = New-Object System.Windows.Forms.Form
    $add_subreddit_form.FormBorderStyle = 'Fixed3D'
    $add_subreddit_form.BackColor             = "#434343"
    $add_subreddit_form.Location = new-object System.Drawing.Point(0, 0)
    $add_subreddit_form.Size = new-object System.Drawing.Size(800, 250)
    $add_subreddit_form.MaximizeBox = $false
    $add_subreddit_form.Icon = $icon
    $add_subreddit_form.SizeGripStyle = "Hide"
    if($mode -eq "Add"){$add_subreddit_form.Text = "Add Subreddit"}
    if($mode -eq "Edit"){$add_subreddit_form.Text = "Edit Subreddit"}
    $add_subreddit_form.TabIndex = 0
    $add_subreddit_form.Font = "Copperplate Gothic,8.1"
    #$add_subreddit_form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen


    $add_subreddit_title                          = New-Object system.Windows.Forms.Label
    if($mode -eq "Add"){$add_subreddit_title.Text = "Add Subreddit or Reddit User"}
    if($mode -eq "Edit"){$add_subreddit_title.Text = "Edit Subreddit or Reddit User"}
    $add_subreddit_title.ForeColor                = "White"
    $add_subreddit_title.TextAlign                   = 'MiddleCenter'
    $add_subreddit_title.width                    = $add_subreddit_form.Width
    $add_subreddit_title.height                   = 30
    $add_subreddit_title.Font                     = "Copperplate Gothic,10"
    $add_subreddit_title.location                 = New-Object System.Drawing.Size((($add_subreddit_form.width / 2) - ($add_subreddit_form.width / 2)),10)
    $add_subreddit_form.controls.Add($add_subreddit_title);


    $button_Save_Reddit = New-Object System.Windows.Forms.Button
    $button_Save_Reddit.Location = New-Object System.Drawing.Size((($add_subreddit_form.width / 2) - 180),170)
    $button_Save_Reddit.Size = "180, 23"
    $button_Save_Reddit.ForeColor = "#999999"
    $button_Save_Reddit.Backcolor = "#606060"
    $button_Save_Reddit.Text = "Save"
    $button_Save_Reddit.Enabled = "$false"
    $button_Save_Reddit.add_Click({
        
        save_subreddit
    
    })
    $add_subreddit_form.Controls.Add($button_Save_Reddit)

    $button_Cancel_Reddit = New-Object System.Windows.Forms.Button
    $button_Cancel_Reddit.Location = New-Object System.Drawing.Size((($add_subreddit_form.width / 2) + 20),170)
    $button_Cancel_Reddit.Size = "180, 23"
    $button_Cancel_Reddit.ForeColor = "White"
    $button_Cancel_Reddit.Backcolor = "#606060"
    $button_Cancel_Reddit.Text = "Cancel"
    $button_Cancel_Reddit.add_Click({  
        [void]$add_subreddit_form.close();
    })
    $add_subreddit_form.Controls.Add($button_Cancel_Reddit)


    ##################################################################################
    ###########Add Subreddit Label
    $y_pos = 45
    $add_subreddit_label = New-Object System.Windows.Forms.Label 
    $add_subreddit_label.Location = "15,$y_pos"
    $add_subreddit_label.Size = "177,23"
    $add_subreddit_label.ForeColor = "White"
    $add_subreddit_label.Text = "Paste Subreddit URL:"
    $add_subreddit_form.Controls.Add($add_subreddit_label)


    ##################################################################################
    ###########Add Subreddit Input

    $add_subreddit_input                         = New-Object system.Windows.Forms.TextBox                       
    $add_subreddit_input.AutoSize                 = $true
    $add_subreddit_input.ForeColor                = "Black"
    $add_subreddit_input.BackColor                = "White"
    $add_subreddit_input.Anchor                   = 'top,left'
    $add_subreddit_input.width                    = ($add_subreddit_form.Width - 210)
    $add_subreddit_input.height                   = 3
    $add_subreddit_input.location                 = New-Object System.Drawing.Point(195,$y_pos)
    if($mode -eq "Edit")
    {
        $add_subreddit_input.Text = "https://www.reddit.com/$entry" 
        $add_subreddit_input.AccessibleName = "https://www.reddit.com/$entry"
    }
    else
    {
        $add_subreddit_input.Text = "https://www.reddit.com/r/"
        $add_subreddit_input.AccessibleName = "";
    }
    $add_subreddit_input.Add_TextChanged({    
                   add_subreddit_form_checks
    })
    $add_subreddit_form.controls.Add($add_subreddit_input);

    ##################################################################################
    ###########Output Directory Label
    $y_pos = $y_pos + 30
    $subreddit_output_label = New-Object System.Windows.Forms.Label 
    $subreddit_output_label.Location = "15,$y_pos"
    $subreddit_output_label.Size = "177,23"
    $subreddit_output_label.ForeColor = "White"
    $subreddit_output_label.Text = "Subreddit Output Dir:"
    $add_subreddit_form.Controls.Add($subreddit_output_label)

    ##################################################################################
    ###########Add Subreddit Output

    $add_subreddit_output                         = New-Object system.Windows.Forms.TextBox                       
    $add_subreddit_output.AutoSize                 = $true
    $add_subreddit_output.ForeColor                = "Black"
    $add_subreddit_output.BackColor                = "White"
    $add_subreddit_output.Anchor                   = 'top,left'
    $add_subreddit_output.width                    = ($add_subreddit_form.Width - 320)
    $add_subreddit_output.height                   = 30
    $add_subreddit_output.location                 = New-Object System.Drawing.Point(195,$y_pos)
    $add_subreddit_output.text                     = $settings["DEFAULT_OUTPUT_DIR"]
    $add_subreddit_output.Add_TextChanged({
               add_subreddit_form_checks
                   
    })
    $add_subreddit_form.controls.Add($add_subreddit_output);

    ##################################################################################
    ###########Browse Output
    $browse_output_button          = New-Object System.Windows.Forms.Button
    $browse_output_button.ForeColor = "White"
    $browse_output_button.Backcolor = "#606060"
    $browse_output_button.Width     = 110
    $browse_output_button.height     = 25
    $browse_output_button.Location  = New-Object System.Drawing.Point(($add_subreddit_output.location.x + $add_subreddit_output.width),($y_pos -2));  
    $browse_output_button.Text      ="Browse"
    $browse_output_button.Add_Click({

        $foldername = New-Object System.Windows.Forms.FolderBrowserDialog
        $foldername.Description = "Select a folder"
        $foldername.rootfolder = "MyComputer"
        if($add_subreddit_output.text)
        {
            if(Test-Path -literalpath $add_subreddit_output.text)
            {
                $foldername.SelectedPath = $add_subreddit_output.text
            }
        }
        if($foldername.ShowDialog() -eq "OK")
        {
            $folder += $foldername.SelectedPath
        }
        $add_subreddit_output.text = $folder
        add_subreddit_form_checks
    });
    $add_subreddit_form.controls.Add($browse_output_button) 

    ##################################################################################
    ###########Minimum Media Width Label
    $y_pos = $y_pos + 30
    $minimum_media_width_label = New-Object System.Windows.Forms.Label 
    $minimum_media_width_label.Location = "15,$y_pos"
    $minimum_media_width_label.Size = "177,23"
    $minimum_media_width_label.ForeColor = "White"
    $minimum_media_width_label.Text = "Minimum Width:"
    $add_subreddit_form.Controls.Add($minimum_media_width_label)

    ##################################################################################
    ###########Minimum Media Width
    $minimum_media_width_input                         = New-Object system.Windows.Forms.TextBox                       
    $minimum_media_width_input.AutoSize                 = $true
    $minimum_media_width_input.ForeColor                = "Black"
    $minimum_media_width_input.BackColor                = "White"
    $minimum_media_width_input.Anchor                   = 'top,left'
    $minimum_media_width_input.width                    = 100
    $minimum_media_width_input.height                   = 30
    $minimum_media_width_input.location                 = New-Object System.Drawing.Point(195,($y_pos -2))
    $minimum_media_width_input.text                     = $script:settings['DEFAULT_MIN_WIDTH']
    $minimum_media_width_input.add_lostfocus({
        
        if(!($this.text -match '^[0-9]+$'))
        {
            $this.text = 0;
        }
        else
        {
            if($this.text.length -ge 2)
            {
                $this.text = $this.text -replace '^0',''
            }
            else
            {
                $this.text = 0;
            }
        }
                
        #add_subreddit_form_checks       
    })

    $add_subreddit_form.controls.Add($minimum_media_width_input)

    ##################################################################################
    ###########Enable Images Checkbox
    $enable_images_checkbox = new-object System.Windows.Forms.checkbox
    $enable_images_checkbox.Location = new-object System.Drawing.Size(($minimum_media_width_input.Location.x + $minimum_media_width_input.width + 150),($y_pos - 5));
    $enable_images_checkbox.Size = new-object System.Drawing.Size(200,30)
    $enable_images_checkbox.ForeColor                = "White"
    $enable_images_checkbox.name = "Enable Video Downloads"
    if($settings["DEFAULT_ENABLE_IMAGES"] -eq "False")
    {
        $enable_images_checkbox.Checked = $false
        $enable_images_checkbox.text = "Images Disabled"
    }
    else
    {
        $enable_images_checkbox.Checked = $true
        $enable_images_checkbox.text = "Images Enabled"
    }

    $enable_images_checkbox.Add_CheckStateChanged({
        if($this.Checked -eq $true)
        {
            $this.text = "Images Enabled"
        }
        else
        {
            $this.text = "Images Disabled"
        }
    })
    $add_subreddit_form.controls.Add($enable_images_checkbox)

    ##################################################################################
    ###########Minimum Media Height label
    $y_pos = $y_pos + 30
    $minimum_media_height_label = New-Object System.Windows.Forms.Label 
    $minimum_media_height_label.Location = "15,$y_pos"
    $minimum_media_height_label.Size = "180,23"
    $minimum_media_height_label.ForeColor = "White"
    $minimum_media_height_label.Text = "Minimum Height:"
    $add_subreddit_form.Controls.Add($minimum_media_height_label)


    ##################################################################################
    ###########Minimum Media Height
    $minimum_media_height_input                         = New-Object system.Windows.Forms.TextBox                       
    $minimum_media_height_input.AutoSize                 = $true
    $minimum_media_height_input.ForeColor                = "Black"
    $minimum_media_height_input.BackColor                = "White"
    $minimum_media_height_input.Anchor                   = 'top,left'
    $minimum_media_height_input.width                    = 100
    $minimum_media_height_input.height                   = 30
    $minimum_media_height_input.location                 = New-Object System.Drawing.Point(195,($y_pos -2))
    $minimum_media_height_input.text                     = $script:settings['DEFAULT_MIN_HEIGHT']
    $minimum_media_height_input.add_lostfocus({
        if(!($this.text -match '^[0-9]+$'))
        {
            $this.text = 0;
        }
        else
        {
            if($this.text.length -ge 2)
            {
                $this.text = $this.text -replace '^0',''
            }
            else
            {
                $this.text = 0;
            }
        }
                
        #add_subreddit_form_checks       
    })
    $add_subreddit_form.controls.Add($minimum_media_height_input)

    ##################################################################################
    ###########Enable Videos Checkbox
    $enable_videos_checkbox = new-object System.Windows.Forms.checkbox
    $enable_videos_checkbox.Location = new-object System.Drawing.Size(($minimum_media_height_input.Location.x + $minimum_media_height_input.width + 150),($y_pos - 5));
    $enable_videos_checkbox.Size = new-object System.Drawing.Size(200,30)
    $enable_videos_checkbox.ForeColor                = "White"
    $enable_videos_checkbox.name = "Enable Video Downloads"
    if($settings["DEFAULT_ENABLE_VIDEOS"] -eq "False")
    {
        $enable_videos_checkbox.Checked = $false
        $enable_videos_checkbox.text = "Videos Disabled"
    }
    else
    {
        $enable_videos_checkbox.Checked = $true
        $enable_videos_checkbox.text = "Videos Enabled"
    }

    $enable_videos_checkbox.Add_CheckStateChanged({
        if($this.Checked -eq $true)
        {
            $this.text = "Videos Enabled"
        }
        else
        {
            $this.text = "Videos Disabled"
        }
    })
    $add_subreddit_form.controls.Add($enable_videos_checkbox)

    if($mode -eq "Edit")
    {
            $entry_array = csv_line_to_array $script:site_list[$entry]
            $add_subreddit_output.text = $entry_array[1]
            $minimum_media_height_input.text = $entry_array[2]
            $minimum_media_width_input.text = $entry_array[3]
            if($entry_array[4] -match "True")
            {
               $enable_images_checkbox.checked = $true
            }
            else
            {
                $enable_images_checkbox.checked = $false
            }
            if($entry_array[5] -match "True")
            {
               $enable_videos_checkbox.checked = $true 
            }
            else
            {
                $enable_videos_checkbox.checked = $false
            }
            add_subreddit_form_checks
    }

    $add_subreddit_form.ShowDialog()
}
################################################################################
######Add Subreddit Form Checks#################################################
function add_subreddit_form_checks
{
    $errors = 0;

    $url = $add_subreddit_input.text
    
    $output_dir = $add_subreddit_output.text
    if(!($url -match '(http[s]?|[s]?ftp[s]?)(:\/\/)([^\s,]+)' -and (($url -match "reddit.com/u/[a-z0-9][a-z0-9][a-z0-9]") -or ($url -match "reddit.com/r/[a-z0-9][a-z0-9][a-z0-9]"))))
    {
        $errors = 1;
    }
    else
    {
        $url_split = $url -split "https://www.reddit.com/|/"
        $subtype = $url_split[1]
        $subreddit = $url_split[2]
        $complete = "$subtype/$subreddit"
        if(!($subtype -match "u|r"))
        {
            $errors = 1
        }
        else
        {
            if($script:site_list[$complete])
            {
                if($mode -ne "Edit")
                {
                    $errors = 1;
                    $message = "This Subreddit Already Exists"
                    [System.Windows.MessageBox]::Show($message,"No List",'Ok')
                }
            }
            else
            {
                $add_subreddit_input.text = "https://www.reddit.com/$complete"
            }
        }
        
    }
    if($output_dir)
    {
        if(!(Test-path -literalpath $output_dir -PathType Container))
        {
            $errors = 1;
        }
    }
    else
    {
        $errors = 1;
    }
    if($errors -eq 1)
    {
        $button_Save_Reddit.ForeColor = "#999999"
        $button_Save_Reddit.Enabled = "$false"
    }
    else
    {
        $button_Save_Reddit.ForeColor = "white"
        $button_Save_Reddit.Enabled = "$true"
    }
}
################################################################################
######Add Subreddit Form Checks#################################################
function save_subreddit
{
    write-host saving
    $url = $add_subreddit_input.text
    $url_split = $url -split "https://www.reddit.com/|/"
    $subtype = $url_split[1]
    $subreddit = $url_split[2]
    $complete = "$subtype/$subreddit"

    ################If Changed URL Key to New Key
    if($add_subreddit_input.AccessibleName -ne $url)
    {
        $old_url = $add_subreddit_input.AccessibleName
        $old_url_split = $old_url -split "https://www.reddit.com/|/"
        $old_subtype = $old_url_split[1]
        $old_subreddit = $old_url_split[2]
        $old_complete = "$old_subtype/$old_subreddit"
        if($script:site_list.ContainsKey($old_complete))
        {
            $script:site_list.remove($old_complete);
        }
    }

    $output_dir = $add_subreddit_output.text
    $min_height = $minimum_media_height_input.text
    $min_width  = $minimum_media_width_input.text
    $videos = $enable_videos_checkbox.checked
    $images = $enable_images_checkbox.checked
    $script:settings["DEFAULT_MIN_HEIGHT"] = $min_height
    $script:settings["DEFAULT_MIN_WIDTH"] = $min_width
    $script:settings["DEFAULT_ENABLE_VIDEOS"] = $output_dir
    $script:settings["DEFAULT_ENABLE_IMAGES"] = $images
    $script:settings["DEFAULT_ENABLE_VIDEOS"] = $videos
    $script:settings["DEFAULT_OUTPUT_DIR"] = $output_dir
    #write-host $url
    #write-host $output_dir
    #write-host $min_height
    #write-host $min_width
    #write-host $videos
    #write-host $images
    if($script:site_list.ContainsKey($complete))
    {
        #Editing
        $line = "";
        $line = csv_write_line $line "True"
        $line = csv_write_line $line $output_dir
        $line = csv_write_line $line $min_height
        $line = csv_write_line $line $min_width       
        $line = csv_write_line $line $images
        $line = csv_write_line $line $videos
        $script:site_list[$complete] = $line
    }
    else
    {
        #Adding New
        $line = "";
        $line = csv_write_line $line "True"
        $line = csv_write_line $line $output_dir
        $line = csv_write_line $line $min_height
        $line = csv_write_line $line $min_width
        $line = csv_write_line $line $images
        $line = csv_write_line $line $videos
        $script:site_list.Add($complete,$line);      
    }
    update_settings
    update_reddits
    $add_subreddit_form.close();
}
################################################################################
######Initial Checks############################################################
function initial_checks
{
    if(!(Test-Path -LiteralPath "$dir\Resources"))
    {
        New-Item  -ItemType directory -Path "$dir\Resources"
    }
    if(!(Test-Path -LiteralPath "$dir\Resources\Cache"))
    {
        New-Item  -ItemType directory -Path "$dir\Resources\Cache"
    }
    if(!(Test-Path -LiteralPath "$dir\Downloads"))
    {
        New-Item  -ItemType directory -Path "$dir\Downloads"
    }


    ###################################################################################
    ###Build Default Settings #########################################################
    if(!(Test-Path -LiteralPath "$dir\Resources\Settings.csv"))
    {
        $script:settings['DEFAULT_OUTPUT_DIR'] = $dir
        $script:settings["DEFAULT_ENABLE_VIDEOS"] = "True";
        $script:settings["DEFAULT_ENABLE_IMAGES"] = "True";
        $script:settings["DEFAULT_MIN_HEIGHT"] = 0
        $script:settings["DEFAULT_MIN_WIDTH"] = 0
        $script:settings["SLEEP_TIMER"] = 60;
        $script:settings["CLOCK_SPEED"] = 100
        $script:settings["FFMPEG"] = "";
        $script:settings["FFPROBE"] = "";
        update_settings
    }


    ###################################################################################
    ###Load Settings ##################################################################
    load_settings



    ###################################################################################
    ###Clock Speed ####################################################################
    if(!($script:settings['CLOCK_SPEED'] -match "\d+"))
    {
        $script:settings['CLOCK_SPEED'] = 100;
    }

    ###################################################################################
    ###################################################################################
    if(($script:settings["FFMPEG"] -eq $null) -or (!(Test-Path -LiteralPath $script:settings["FFMPEG"])) -or ($script:settings["FFPROBE"] -eq $null) -or (!(Test-Path -LiteralPath $script:settings["FFPROBE"])))
    {
        ffmpeg_settings
    }

    ###################################################################################
    if(!(Test-Path -LiteralPath "$dir\Resources\Reddits.csv"))
    {
        #########Create Default Loads
        $writer = new-object system.IO.StreamWriter("$dir\Resources\Reddits.csv",$true)
        $writer.write("SUBREDDIT,ENABLED,TARGET DIRECTORY,MINIMUM HEIGHT,MINIMUM WIDTH,IMAGES?,VIDEOS?`r`n");
        $writer.write("r/multiwall,True,$dir\Downloads,0,0,True,True`r`n");
        $writer.write("r/wallpaper,True,$dir\Downloads,0,0,True,True`r`n");
        $writer.write("r/wallpapers,True,$dir\Downloads,0,0,True,True`r`n");
        $writer.write("r/offensive_wallpapers,True,$dir\Downloads,True,$dir,0,0,True,True`r`n");
        $writer.close();
    }
    ########Read Reddits to Hash
    $reader = [System.IO.File]::OpenText("$dir\Resources\Reddits.csv")
    while($null -ne ($line = $reader.ReadLine()))
    {
        if($line -match "r/|u/")
        {
            [Array]$line_split = csv_line_to_array $line
            $reddit = $line_split[0]
            if(!($script:site_list.Contains($reddit)))
            {
                $line = $line -replace "^$reddit,",""
                $script:site_list.Add($reddit,"$line");
            }
        }
            
    }
    $reader.close();
    ###################################################################################
    if(!(Test-Path -LiteralPath "$dir\Resources\Hashes.csv"))
    {
        New-Item "$dir\Resources\Hashes.csv" -ItemType File
    }
    ###################################################################################
    if(!(Test-Path -LiteralPath "$dir\Resources\Duplicates.csv"))
    {
        New-Item "$dir\Resources\Duplicates.csv" -ItemType File
    }

    $Script:Timer.Interval = $script:settings['CLOCK_SPEED'];
    $Script:Timer.Start()
    $Script:Timer.Add_Tick({Idle_Timer})
}
################################################################################
######Load Settings##############################################################
function load_settings
{
    if(Test-Path -LiteralPath "$dir\Resources\Settings.csv")
    {
        $line_count = 0;
        $reader = [System.IO.File]::OpenText("$dir\Resources\Settings.csv")
        while($null -ne ($line = $reader.ReadLine()))
        {
            $line_count++;
            if($line_count -ne 1)
            {
                ($key,$value) = $line -split ',',2
                if(!($script:settings.containskey($key)))
                {
                    $script:settings.Add($key,$value);
                }
            } 
        }
        $reader.close(); 
    }
}
#################################################################################
######Save Settings##############################################################
function ffmpeg_settings
{
    ##################################################################################
    ###########Main Form
    $script:Form = New-Object System.Windows.Forms.Form
    $script:Form.Location = "200, 200"
    $script:Form.Font = "Copperplate Gothic,8.1"
    $script:Form.FormBorderStyle = "FixedDialog"
    $script:Form.ForeColor = "Black"
    $script:Form.BackColor = "#434343"
    $script:Form.Text = "  FFmpeg & FFprobe Required"
    $script:Form.Width = 1000
    $script:Form.Height = 300


    ##################################################################################
    ###########Title Main
    $y_pos = 15
    $title1            = New-Object System.Windows.Forms.Label   
    $title1.Font       = New-Object System.Drawing.Font("Copperplate Gothic Bold",15,[System.Drawing.FontStyle]::Regular)
    $title1.Text       = "FFmpeg && FFprobe Required"
    $title1.TextAlign  = "MiddleCenter"
    $title1.Width      = $script:Form.Width
    $title1.height     = 35
    $title1.ForeColor  = "white"
    $title1.Location   = New-Object System.Drawing.Size((($script:Form.width / 2) - ($script:Form.width / 2)),$y_pos)
    $script:Form.Controls.Add($title1)


    ##################################################################################
    ###########ffmpeg Location Label
    $y_pos = $y_pos + 85
    $ffmpeg_location_label1 = New-Object System.Windows.Forms.Label 
    $ffmpeg_location_label1.Location = New-Object System.Drawing.Point(15,($y_pos))
    $ffmpeg_location_label1.Size = "250, 23"
    $ffmpeg_location_label1.anchor = "Top"
    $ffmpeg_location_label1.ForeColor = "White"
    $ffmpeg_location_label1.Text = "FFmpeg Location:   "
    $ffmpeg_location_label1.TextAlign  = "MiddleRight"
    $ffmpeg_location_label1.Font = [Drawing.Font]::New("Times New Roman", 12)
    $script:Form.Controls.Add($ffmpeg_location_label1)

    ##################################################################################
    ###########Scan Directory Input
    $ffmpeg_box1 = New-Object System.Windows.Forms.TextBox
    $ffmpeg_box2 = New-Object System.Windows.Forms.TextBox
    $ffmpeg_box1.Location = New-Object System.Drawing.Point(($ffmpeg_location_label1.location.x + $ffmpeg_location_label1.width + 3),($y_pos))
    $ffmpeg_box1.anchor = "Top"
    $ffmpeg_box1.width = 500
    $ffmpeg_box1.Height = 40
    $ffmpeg_box1.font = New-Object System.Drawing.Font("Arial",11,[System.Drawing.FontStyle]::Regular)
    if(($script:settings['FFMPEG'] -eq "") -or ($script:settings['FFMPEG'] -eq $null) -or (!(Test-Path -literalpath $script:settings['FFMPEG'])))
    {
        $ffmpeg_box1.text = "Browse or Enter a file path for FFmpeg.exe"
    }
    else
    {
        $ffmpeg_box1.text = $script:settings['FFMPEG']
        $ffmpeg_location_label1.ForeColor = "Green"
    }
    $ffmpeg_box1.Add_Click({
        if($ffmpeg_box1.Text -eq "Browse or Enter a file path for FFmpeg.exe")
        {
            $ffmpeg_box1.Text = ""
            $ffmpeg_box2.Text = ""
        }
    })
    $ffmpeg_box1.Add_TextChanged({
        
            if(($this.text -ne $Null) -and ($this.text -ne "") -and (Test-Path -literalpath $this.text) -and ($this.text -match ".exe$"))
            {
                $script:settings['FFMPEG'] = $ffmpeg_box1.Text
                $ffmpeg_box2.Text = $script:settings['FFMPEG']
                $ffmpeg_location_label1.ForeColor = "Green"
                update_settings
            }
            else
            {
                $script:settings['FFMPEG'] = "";
                $ffmpeg_location_label1.ForeColor = "White"
                update_settings
            }
    })
    $ffmpeg_box1.Add_lostFocus({

        if(($script:settings['FFMPEG'] -eq "") -or ($script:settings['FFMPEG'] -eq $null) -or (!(Test-Path -literalpath $script:settings['FFMPEG'])))
        {
            $this.text = "Browse or Enter a file path for FFmpeg.exe"
            $ffmpeg_box2.Text = "Browse or Enter a file path for FFmpeg.exe"
        }
    })
    $script:Form.Controls.Add($ffmpeg_box1)
    
    ##################################################################################
    ###########Browse Button 1
    $browse_button1 = New-Object System.Windows.Forms.Button
    $browse_button1.Location= New-Object System.Drawing.Size(($ffmpeg_box1.location.x + $ffmpeg_box1.width + 3),($y_pos + 1))
    $browse_button1.BackColor = "#606060"
    $browse_button1.ForeColor = "White"
    $browse_button1.anchor = "Top"
    $browse_button1.Width=100
    $browse_button1.Height=22
    $browse_button1.Text='Browse'
    $browse_button1.Font = [Drawing.Font]::New("Times New Roman", 9)
    $browse_button1.Add_Click(
    {    
        $return = prompt_for_file_exe
        if($return.length -ge 3)
        {
            $ffmpeg_box1.text = $return
        }
    })
    $script:Form.Controls.Add($browse_button1)


    ##################################################################################
    ###########ffprobe Location Label
    $y_pos = $y_pos + 85
    $ffprobe_location_label1 = New-Object System.Windows.Forms.Label 
    $ffprobe_location_label1.Location = New-Object System.Drawing.Point(15,($y_pos))
    $ffprobe_location_label1.Size = "250, 23"
    $ffprobe_location_label1.anchor = "Top"
    $ffprobe_location_label1.ForeColor = "White"
    $ffprobe_location_label1.Text = "FFprobe Location:   "
    $ffprobe_location_label1.TextAlign  = "MiddleRight"
    $ffprobe_location_label1.Font = [Drawing.Font]::New("Times New Roman", 12)
    $script:Form.Controls.Add($ffprobe_location_label1)

    ##################################################################################
    ###########Scan Directory Input
    $ffprobe_box1 = New-Object System.Windows.Forms.TextBox
    $ffprobe_box2 = New-Object System.Windows.Forms.TextBox
    $ffprobe_box1.Location = New-Object System.Drawing.Point(($ffprobe_location_label1.location.x + $ffprobe_location_label1.width + 3),($y_pos))
    $ffprobe_box1.anchor = "Top"
    $ffprobe_box1.width = 500
    $ffprobe_box1.Height = 40
    $ffprobe_box1.font = New-Object System.Drawing.Font("Arial",11,[System.Drawing.FontStyle]::Regular)
    if(($script:settings['FFPROBE'] -eq "") -or ($script:settings['FFPROBE'] -eq $null) -or (!(Test-Path -literalpath $script:settings['FFPROBE'])))
    {
        $ffprobe_box1.text = "Browse or Enter a file path for FFprobe.exe"
    }
    else
    {
        $ffprobe_box1.text = $script:settings['FFPROBE']
        $ffprobe_location_label1.ForeColor = "Green"
    }
    $ffprobe_box1.Add_Click({
        if($ffprobe_box1.Text -eq "Browse or Enter a file path for FFprobe.exe")
        {
            $ffprobe_box1.Text = ""
            $ffprobe_box2.Text = ""
        }
    })
    $ffprobe_box1.Add_TextChanged({
        
            if(($this.text -ne $Null) -and ($this.text -ne "") -and (Test-Path -literalpath $this.text) -and ($this.text -match ".exe$"))
            {
                $script:settings['FFPROBE'] = $ffprobe_box1.Text
                $ffprobe_box2.Text = $script:settings['FFPROBE']
                $ffprobe_location_label1.ForeColor = "Green"
                update_settings
                if((Test-Path -LiteralPath $script:settings['FFPROBE']) -and (Test-Path -LiteralPath $script:settings['FFMPEG']))
                {
                    $script:Form.Close();
                }
            }
            else
            {
                $script:settings['FFPROBE'] = "";
                $ffprobe_location_label1.ForeColor = "White"
                update_settings
                if((Test-Path -LiteralPath $script:settings['FFPROBE']) -and (Test-Path -LiteralPath $script:settings['FFMPEG']))
                {
                    $script:Form.Close();
                }
            }
    })
    $ffprobe_box1.Add_lostFocus({

        if(($script:settings['FFPROBE'] -eq "") -or ($script:settings['FFPROBE'] -eq $null) -or (!(Test-Path -literalpath $script:settings['FFPROBE'])))
        {
            $this.text = "Browse or Enter a file path for FFprobe.exe"
            $ffprobe_box2.Text = "Browse or Enter a file path for FFprobe.exe"
        }
    })
    $script:Form.Controls.Add($ffprobe_box1)
    
    ##################################################################################
    ###########Browse Button 1
    $browse_button2 = New-Object System.Windows.Forms.Button
    $browse_button2.Location= New-Object System.Drawing.Size(($ffprobe_box1.location.x + $ffprobe_box1.width + 3),($y_pos + 1))
    $browse_button2.BackColor = "#606060"
    $browse_button2.ForeColor = "White"
    $browse_button2.anchor = "Top"
    $browse_button2.Width=100
    $browse_button2.Height=22
    $browse_button2.Text='Browse'
    $browse_button2.Font = [Drawing.Font]::New("Times New Roman", 9)
    $browse_button2.Add_Click(
    {    
        $return = prompt_for_file_exe
        if($return.length -ge 3)
        {
            $ffprobe_box1.text = $return
        }
    })
    $script:Form.Controls.Add($browse_button2)
    Start-Process "https://ffmpeg.org/download.html#build-windows"
    [void] $script:Form.ShowDialog()
}
##################################################################################
######Prompt for File Exe#########################################################
function prompt_for_file_exe()
{  
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")|Out-Null
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = "::{20D04FE0-3AEA-1069-A2D8-08002B30309D}"
    $OpenFileDialog.filter = "(*.exe)|*.exe;"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}
#################################################################################
######Save Settings##############################################################
function update_settings
{
    if(Test-Path -literalpath "$dir\Resources\Settings.csv")
    {
        Remove-Item -literalpath "$dir\Resources\Settings.csv"
    }
    $settings_writer = new-object system.IO.StreamWriter("$dir\Resources\Settings.csv",$true)
    $settings_writer.write("PROPERTY,VALUE`r`n");
    foreach($setting in $script:settings.getEnumerator() | Sort key)                  #Loop through Input Entries
    {
            $setting_key = $setting.Key                                               
            $setting_value = $setting.Value
            $settings_writer.write("$setting_key,$setting_value`r`n");
    }
    $settings_writer.close();
}
################################################################################
######Update Reddits############################################################
function update_reddits
{
    ##################################################################################
    ###########Update Reddit File
    $writer = new-object system.IO.StreamWriter("$dir\Resources\Reddits_Temp.csv",$true)
    $writer.write("SUBREDDIT,ENABLED,TARGET DIRECTORY,MINIMUM HEIGHT,MINIMUM WIDTH,IMAGES?,VIDEOS?`r`n");
    foreach($reddit in $script:site_list.getEnumerator() | sort key)
    {
        $site = $reddit.key
        $entry_array = $reddit.value
        $writer.write("$site,$entry_array`r`n");
    }
    $writer.close();
    if(Test-Path -LiteralPath "$dir\Resources\Reddits_Temp.csv")
    {
        if(Test-Path -LiteralPath "$dir\Resources\Reddits.csv")
        {
            Remove-Item -LiteralPath "$dir\Resources\Reddits.csv"
        }
        Rename-Item -LiteralPath "$dir\Resources\Reddits_Temp.csv" "$dir\Resources\Reddits.csv"
    }
    ##################################################################################
    ###########Update List Box
    $place_holder = $script:reddit_list_box.SelectedItem
    $script:reddit_list_box.Items.Clear();

    [void] $script:reddit_list_box.Items.add("Select All")
    $script:reddit_list_box.SetItemChecked($script:reddit_list_box.Items.IndexOf("Select All"), $true);
    $script:list_box_select_status = 1;
    if($script:site_list.count -ne 0)
    {
        foreach($reddit in $script:site_list.getEnumerator() | sort key)
        {
            $site = $reddit.key
            $entry_array = csv_line_to_array $reddit.value
            [void] $script:reddit_list_box.Items.add("$site")
            if($entry_array[0] -eq "True")
            {
                if($script:site_list.contains("$site")) #Check the items that the user had checked last
                {
                    $script:reddit_list_box.SetItemChecked($script:reddit_list_box.Items.IndexOf("$site"), $true);
                    ##Update Select Item
                        if($script:list_box_select_status -eq 1)
                        {
                            $script:reddit_list_box.SetItemChecked($script:reddit_list_box.Items.IndexOf("Select All"),$true);
                            $script:reddit_list_box.items[$script:reddit_list_box.Items.IndexOf("Select All")] = "Select None"
                            $script:list_box_select_status = 0;
                        }
                }
                else
                {
                    if($script:site_list.contains("$site")) #Check the items that the user had checked last
                    {
                        $script:reddit_list_box.SetItemChecked($script:reddit_list_box.Items.IndexOf("$site"), $false);
                        
                    }
                } 
            }  
        }
        if($script:reddit_list_box.Items.Contains("$place_holder"))
        {
            $script:reddit_list_box.SetSelected($script:reddit_list_box.Items.IndexOf("$place_holder"),$true);
        }
    }
}
################################################################################
######CSV Line to Array#########################################################
function csv_line_to_array ($line)
{
    if($line -match "^,")
    {
        $line = ",$line"; 
    }
    Select-String '(?:^|,)(?=[^"]|(")?)"?((?(1)[^"]*|[^,"]*))"?(?=,|$)' -input $line -AllMatches | Foreach { [System.Collections.ArrayList]$line_split = $_.matches -replace '^,|"',''}
    return $line_split
}
################################################################################
######CSV Write Line #########################################################
function csv_write_line ($write_line,$data)
{
    ##################################################
    #Function checks to see if there is a comma in the data about to be written
    $return = "";
    if($data -match ',')
    {
        $data = '"' + "$data" + '"'
    }
    if($write_line -eq "")
    {
        $return = "$data"
    }
    else
    {
        $return = "$write_line," + "$data"
    }
    return $return
}
##################################################################################
######Cycler######################################################################
function cycler
{
$cycler_job_block = {
##################################################################################
######Cycler Global Vars (JOB) ###################################################
Add-Type -AssemblyName 'System.Windows.Forms'
Add-Type -AssemblyName 'System.Drawing'
Add-Type -AssemblyName 'PresentationFramework'
$script:site_list = $using:site_list;
$script:dir = $using:dir;
$settings = $using:settings;

$script:ffmpeg = $script:settings["FFMPEG"]
$script:ffprobe = $script:settings["FFPROBE"]

$script:duplicates = new-object System.Collections.Hashtable
$script:file_hashes = new-object System.Collections.Hashtable

##################################################################################
######Job Main Function (JOB)#####################################################
function job_main
{

    ##################################################################################
    ######Ingest Hash File############################################################
    write-output "--------------------------------------------------------------------------------------------------------------------------"
    Write-Output "Initializing"
    Write-Output "     Ingesting Media Hashes"
    if(!(Test-Path -LiteralPath "$dir\Resources\Hashes.csv"))
    {
        New-Item "$dir\Resources\Hashes.csv" -ItemType File
    }
    else
    {
        ##################################################################################
        ######Load Hashes ################################################################
        $reader = New-Object IO.StreamReader "$dir\Resources\Hashes.csv"
        $counter = 0;
        while($null -ne ($line = $reader.ReadLine()))
        {
            ($hash,$file) = $line -split ',', 2
            $file = $file -replace "^`"|`"$",""
            if(!($script:file_hashes.Contains($hash)))
            {
                if(Test-Path -LiteralPath $file)
                {
                    $counter++;
                    $script:file_hashes.Add($hash,$file);
                }
            }
        }
        $reader.Close()
    }
    Write-Output "     $counter Media Hashes Ingested"
    ##################################################################################
    ######Ingest Dupicates############################################################
    $script:duplicates = @{};
    Write-Output "     Ingesting Duplicates"
    if(!(Test-Path -LiteralPath "$dir\Resources\Duplicates.csv"))
    {
        New-Item -LiteralPath "$dir\Resources\Duplicates.csv" -ItemType File
    }
    else
    {
        $counter = 0;
        $reader = New-Object IO.StreamReader "$dir\Resources\Duplicates.csv"
        while($null -ne ($line = $reader.ReadLine()))
        {
            if(!($script:duplicates.Contains($line)))
            {
                $counter++;
                $script:duplicates.Add($line,"");
                #write-host $line
            }
        }
        $reader.Close()
    }
    Write-Output "     $counter Duplicates Ingested"
    $site_total = 0;
    ##################################################################################
    ######Calculate On Subreddits#####################################################
    foreach($site in $script:site_list.getEnumerator() | Sort Key)
    {
        if($site.value -match "^True")
        {
            $site_total++;
        }
    }
    ##################################################################################
    ######Cycler######################################################################
    $cycle = 0;
    while($true)
    {
        $cycle++;
        $site_count = 0 
        foreach($site in $script:site_list.getEnumerator() | Sort Key)
        {
            ##################################################################################
            ######Reddit Site Vars############################################################
            Select-String '(?:^|,)(?=[^"]|(")?)"?((?(1)[^"]*|[^,"]*))"?(?=,|$)' -input $site.value -AllMatches | Foreach { [System.Collections.ArrayList]$key_split = $_.matches -replace '^,|"',''}
            $full_url = "https://www.reddit.com/" + $site.key + ".json"
            $enabled    = $key_split[0];
            $output_dir = $key_split[1];
            $min_height = $key_split[2];
            $min_width  = $key_split[3];
            $images_on  = $key_split[4];
            $videos_on  = $key_split[5];
            $sub_dir    = $site.key -replace "r/|u/","";
            $reddit_sub = $site.key

            ##################################################################################
            ######Enabled#####################################################################
            if($enabled -eq "True")
            { 
                $site_count++;
                write-output "-------------------------------------------------------------"
                write-Output "Processing $reddit_sub"
                write-output "PL-Processing $reddit_sub"
                ##################################################################################
                ######Validate Directory##########################################################
                if(!(Test-Path -LiteralPath "$output_dir\$sub_dir"))
                {
                    New-Item -ItemType directory -Path "$output_dir\$sub_dir"
                }
                ##################################################################################
                ######Update Hash File############################################################
                $writer = new-object system.IO.StreamWriter("$dir\Resources\Hashes.csv",$true)
                Get-ChildItem -LiteralPath "$output_dir\$sub_dir" -Recurse -File -ErrorAction SilentlyContinue | where {! $_.PSIsContainer} | sort Name | ForEach-Object {
                    $fullpath = $_.FullName
                    if(!($script:file_hashes.Containsvalue($fullpath)))
                    {
                        $hash = Get-FileHash $fullpath -Algorithm MD5
                        $hash = $hash.hash
                        if(!($script:file_hashes.Contains($hash)) -and (Test-Path -literalpath $fullpath))
                        {
                            $script:file_hashes.Add($hash,$fullpath);
                            $writer.write("$hash,$fullpath`r`n");  
                        }
                        else
                        {
                            #$other_path = $script:file_hashes[$hash]
                            #Write-Output "Dup Maybe1 $fullpath"
                            #write-output "Dup Maybe2 $other_path"
                            #write-output "  "
                            if((Test-path -LiteralPath $script:file_hashes[$hash]) -and (!($script:file_hashes[$hash] -match [regex]::Escape($fullpath))))
                            {
                                write-output "     Duplicate File Removed: $fullpath"
                                Remove-Item -literalpath $fullpath -force
                            }
                            else
                            {
                                $script:file_hashes[$hash] = $fullpath
                            }
                        }
                    }            
                }
                $writer.close();
                ##################################################################################
                ######Start Request###############################################################
                #write-output $full_url
                $response = "";
                try
                {
                    $json_buffer = "$dir\Resources\Cache\Json Buffer.txt"
                    if(Test-Path -LiteralPath $json_buffer){Remove-Item -LiteralPath $json_buffer}
                    Start-BitsTransfer -Source $full_url -Destination $json_buffer -TransferType Download
                    $response = Get-Content -LiteralPath $json_buffer
                }
                catch
                {
                    Write-Output "     Failed Get - Error 1: $full_url"
                    write-output "PL-Failed: $full_url"
                    $failed_buffer = "$dir\Resources\Cache\Failed - $reddit_sub.txt" -replace "r/|u/",""
                    Set-Content -LiteralPath $failed_buffer $response
                }
                if($response.length -lt 200)
                {
                    Write-Output "     Failed Get - Error 2: $full_url"
                    write-output "PL-Failed: $full_url"
                    $failed_buffer = "$dir\Resources\Cache\Failed - $reddit_sub.txt" -replace "r/|u/",""
                    Set-Content -LiteralPath $failed_buffer $response 
                }
                ##################################################################################
                ######Good Request################################################################
                $counter = 0;
                $counter_found = 0;
                if($response.length -gt 200)
                {
                    #Write-Output "     Response Valid"
                    ##################################################################################
                    ######Matching####################################################################
                    $pattern = '(http[s]?)(:\/\/)([^\s,]+)(?=")'
                    $matches = [regex]::Matches($response, $pattern)
        
                    Foreach($media_url in ($matches | Select-Object -Unique) | sort value -Descending)
                    {
                        #write-output "Media URL: $media_url"
                        #Problems with Audio? Check DASHPLAYLIST.mpd file for Reddit API changes
                        $virgin_media_url = $media_url
                        ##################################################################################
                        ######Pre-Duplicate Check#########################################################
                        if(!($script:duplicates.Contains($media_url.value)) -and (!($media_url -match "icon|thumb|award|_96|/comments/"))) #scrub
                        {
                            $counter++
                            $media_url = $media_url -replace '\?source=fallback',""
                            ##################################################################################
                            ######Most Media Check############################################################
                            if((($media_url -match "jpg$|jpeg$|bmp$|gif$|png$|webp$|gifv$") -and ($images_on -eq "True")) -or (($media_url -match "mp4$") -and ($videos_on -eq "True")))
                            {
                                
                                $media_url = $media_url -replace "gifv$","mp4"
                                $save_name = $media_url
                                $save_name = $save_name -replace "/DASH",""
                                $save_name_gui = Split-Path $save_name -Leaf
                                $save_name = "$output_dir\$sub_dir\$save_name_gui"
                                write-output "    "
                                write-output "$save_name"
                                write-output "$media_url"
                                if(!(Test-Path -LiteralPath "$save_name"))
                                {
                                    $counter_found++;
                                    write-output "     $counter_found = $media_url"
                                    write-output "PL-$reddit_sub $counter_found = $save_name_gui"
                                    ##################################################################################
                                    ######Download Dash Video#########################################################
                                    if(($media_url -match ".mp4") -and ($media_url -match "DASH"))
                                    {
                                        ######Clear Cache
                                        if(Test-Path -LiteralPath "$dir\Resources\Cache\video.mp4")
                                        {
                                            Remove-Item -LiteralPath "$dir\Resources\Cache\video.mp4"
                                        }

                                        #####Download Video
                                        write-output "               Downloading: $media_url"
                                        Start-BitsTransfer -Source $media_url -Destination "$dir\Resources\Cache\video.mp4" -TransferType Download
                              

                                        $audio_checks = ("_AUDIO_128","_AUDIO_64","_AUDIO");
                                        foreach($check in $audio_checks)
                                        {
                                            if(Test-Path -LiteralPath "$dir\Resources\Cache\audio.mp4")
                                            {
                                                Remove-Item -LiteralPath "$dir\Resources\Cache\audio.mp4"
                                            }
                                            $audio_url = $media_url
                                            $audio_url = $audio_url -replace "_240|_270|_360|_480|_720|_1080", "$check"
                                            write-output "               Checking Audio: $audio_url"
                                            Start-BitsTransfer -Source $audio_url -Destination "$dir\Resources\Cache\audio.mp4" -TransferType Download
                                            if(Test-Path -LiteralPath "$dir\Resources\Cache\audio.mp4")
                                            {
                                                try
                                                {
                                                    $console = & cmd /u /c  "$script:ffmpeg -i `"$dir\Resources\Cache\video.mp4`" -i `"$dir\Resources\Cache\audio.mp4`" -hide_banner -loglevel error -c copy `"$save_name`" -y"
                                                }
                                                catch
                                                {
                                                    write-output $console
                                                    write-output "Failed Audio"
                                                }
                                                break;
                                            }
                                            else
                                            {
                                                #No Audio File
                                                write-output "               No Audio $save_name_gui"
                                                Move-Item -LiteralPath "$dir\Resources\Cache\video.mp4" "$save_name"
                                            }
                                        }
                                    }
                                    ##################################################################################
                                    ######Download Standard File #####################################################
                                    else 
                                    {
                                        Start-BitsTransfer -Source $media_url -Destination "$save_name" -TransferType Download
                                    }

                                    ##################################################################################
                                    ######Append Duplicates ##########################################################    
                                    $script:duplicates.Add("$virgin_media_url","")
                                    Add-Content "$dir\Resources\Duplicates.csv" "$virgin_media_url"

                                    ##################################################################################
                                    ######Convert Files to PNG/MP4 ################################################### 
                                    $save_name = convert_files $save_name


                                    ##################################################################################
                                    ######Rename with Date ###########################################################
                                    $save_name = rename_file $save_name


                                    ##################################################################################
                                    ######Check Dimensions############################################################
                                    $dimensions = & cmd /u /c  "$script:ffprobe -i `"$filename`" -v error -select_streams v -show_entries stream=width,height -of csv=p=0:s=x"
                                    ([int]$width,[int]$height) = $dimensions -split "x"

                                    if($height -lt $min_height)
                                    {
                                        write-output "          Height too Small $height < $min_height...Deleted"
                                        if(Test-path -LiteralPath $save_name)
                                        {
                                            Remove-Item -LiteralPath $save_name -force
                                        }
                                        write-output "PL-$save_name Height too Small $height < $min_height...Deleted"
                                    }
                                    elseif($width -lt $min_width)
                                    {
                                        write-output "          Width too Small $width < $min_width...Deleted"   
                                        if(Test-path -LiteralPath $save_name)
                                        {
                                            Remove-Item -LiteralPath $save_name -force
                                        }
                                        write-output "PL-Width too Small $width < $min_width...Deleted"
                                    }
                                    
                                    ##################################################################################
                                    ######Post-Duplicate Hash Check###################################################
                                    $hash = Get-FileHash "$save_name" -Algorithm MD5
                                    $hash = $hash.hash
                                    if(!($script:file_hashes.contains($hash)))
                                    {
                                        $script:file_hashes.Add($hash,"$save_name")
                                    }
                                    else
                                    {
                                        $dup = $script:file_hashes[$hash]
                                        write-output "          Duplicate Files:"
                                        write-output "               $dup"
                                        write-output "               $save_name"
                                        if(Test-path -literalpath "$save_name")
                                        {
                                            Remove-Item -literalpath "$save_name" -Force
                                        }
                                        write-output "          Duplicate Deleted"
                                        write-output "PL-Duplicate Deleted: $save_name_gui"
                                        $counter_found--
                                    }
                                }#Image Doesn't Exist
                            }#Most Media Check
                            ##################################################################################
                            ######Externally Hosted###########################################################
                            elseif(($media_url -match "redgif") -and ($media_url -match "watch")  -and ($videos_on -eq "True"))
                            {
                                ##################################################################################
                                ######Get Sub Page################################################################
                                $response = "Failed"
                                [string]$sub_url = $media_url
                                try
                                {
                                    #$response = Invoke-WebRequest -Uri $sub_url -UseBasicParsing
                                    $json_buffer = "$dir\Resources\Cache\Json Sub Buffer.txt"
                                    if(Test-Path -LiteralPath $json_buffer){Remove-Item -LiteralPath $json_buffer}
                                    Start-BitsTransfer -Source $sub_url -Destination $json_buffer -TransferType Download
                                    $response = Get-Content -LiteralPath $json_buffer
                                }
                                catch
                                {
                                    write-output "     Failed External: $media_url"
                                    write-output "PL-Failed: $media_url" 
                                }
                                ##################################################################################
                                ######Process Sub Links###########################################################
                                if($response -ne "Failed")
                                {
                                    $pattern = '(http[s]?)(:\/\/)([^\s,]+)(?=")'
                                    $sub_matches = [regex]::Matches($response, $pattern)
                                    Foreach($external_video in ($sub_matches | Select-Object -Unique))
                                    {
                                        if(($external_video -match "mp4$") -and (!($external_video -match "mobile")))
                                        {
                                            $counter++
                                            $save_name_gui = Split-Path $external_video -Leaf
                                            $save_name = "$output_dir\$sub_dir\$save_name_gui"
                                            if(!(Test-Path -literalpath "$save_name"))
                                            {
                                                $counter_found++;
                                                write-output "     $counter_found = $external_video"
                                                write-output "PL-$reddit_sub $counter_found = $save_name_gui"
                                                ##################################################################################
                                                ######Download Video##############################################################
                                                Start-BitsTransfer -Source $external_video -Destination "$save_name" -TransferType Download
                                                $script:duplicates.Add("$virgin_media_url","")
                                                Add-Content "$dir\Resources\Duplicates.csv" "$virgin_media_url"

                                                ##################################################################################
                                                ######Post-Duplicate Hash Check###################################################
                                                $hash = Get-FileHash "$save_name" -Algorithm MD5
                                                $hash = $hash.hash

                                                if(!($script:file_hashes.contains($hash)))
                                                {
                                                    $script:file_hashes.Add($hash,"$save_name")
                                                }
                                                else
                                                {
                                                    $dup = $script:file_hashes[$hash]
                                                    write-output "          Duplicate Files:"
                                                    write-output "               $dup"
                                                    write-output "               $save_name"
                                                    Remove-Item -literalpath "$save_name" -Force
                                                    write-output "          Duplicate Deleted"
                                                    write-output "PL-Duplicate Deleted: $save_name_gui"
                                                    $counter_found--
                                                }
                                            }#Video Doesn't Exist
                                        }#External Video Match
                                    }#SubMatch loop
                                }#Failed Response
                            }#External Videos
                        }#Pre-Duplicate Check
                    }#Match Loop
                }#Good Response
                write-output "     $counter Items Found $counter_found New"
                write-output "PL-$reddit_sub $counter Items Found $counter_found New"
                write-output " "
                [int]$progress =  ($site_count / $site_total) * 100;
                Write-Output "PB-$progress"
            }#Enabled
        }#Sites Loop
        ##################################################################################
        ######Running Post-Operations#####################################################
        write-output "-------------------------------------------------------------"
        Write-Output "Running Post Operations"
        Write-Output "     Updating Hashes"
        if(Test-Path -LiteralPath "$dir\Resources\Hashes_temp.csv")
        {
            Remove-Item "$dir\Resources\Hashes_temp.csv"
                
        }
        $writer = new-object system.IO.StreamWriter("$dir\Resources\Hashes_temp.csv",$true)
        foreach($hash in $script:file_hashes.getEnumerator() | Sort Value -Descending)
        {
            $value = $hash.value 
            $key = $hash.key
            if(Test-Path -literalpath $hash.value)
            {
                $writer.write("$key,$value`r`n");
            }
        }
        $writer.Close();
        if(Test-Path -literalpath "$dir\Resources\Hashes_temp.csv")
        {
            if(Test-Path -LiteralPath "$dir\Resources\Hashes.csv")
            {
                Remove-Item -LiteralPath "$dir\Resources\Hashes.csv"
            }
            Rename-Item -LiteralPath "$dir\Resources\Hashes_temp.csv" "$dir\Resources\Hashes.csv"
            Write-Output "     Hashes Updated"
        }
        write-output "--------------------------------------------------------------------------------------------------------------------------"
        ##################################################################################
        ##################################################################################
        write-output "Sleeping..."

        [int]$minute_end = $script:settings["SLEEP_TIMER"]
        $start = (Get-Date)
        $end = ($start).Addminutes($minute_end)
        While($start -lt $end)
        {
            Start-Sleep -Seconds 1
            $start = (Get-Date)         
            $duration = $end - $start
            $minutes =  ($duration).minutes
            $seconds =  ($duration).seconds       
            [int]$status = (((($end - $start).totalseconds) / ([int]$minute_end * 60)) * 100)
            if($status -le 0){$status = 0}
            Write-Output "PB-$status"       
            write-output "PL-Sleeping... Time Before Next Launch $minutes Minutes $seconds Seconds"
        }
    }#Cylce
}#Job Main
##################################################################################
######Rename File (Job)###########################################################
function rename_file($save_name)
{
    $file = Get-Item -LiteralPath $save_name
    $old_name = $file.FullName
    $ext = $file.Extension
    $file_dir = Split-Path  $file.FullName -Parent
    $file_name = $file.Name
    $file_name_split = $file_name -split " |\.|_|-"
    $date = (Get-Date).ToString("yyyy-MM-dd HH.mm.ss")

    $pre = "NA"
    if($ext -match "PNG$|JPEG$|JPG$")
    {
        $pre = "IMG"
    }
    if($ext -match "mp4$|mkv$")
    {
        $pre = "VID"       
    }
    foreach($split in $file_name_split)
    {
        if($split.length -gt $longest_word.Length)
        {
            $longest_word = $split
        }
    }
    $save_name = "$file_dir\$pre $date $longest_word$ext"
    if(Test-Path -LiteralPath $save_name)
    {
        $count = 0;
        while($count -lt 100)
        {
            $count++
            $count_buffer = ("$count").PadLeft(3,"0");
            $save_name = "$file_dir\$pre $date $longest_word $count_buffer$ext"
            if(!(Test-Path -LiteralPath $save_name))
            {
                break;
            }
        }
    }
    Rename-Item -LiteralPath $old_name $save_name
    return $save_name
}
##################################################################################
######Convert Files (Job)#########################################################
function convert_files($filename)
{
    write-output "-----------------------"
    $old_ext = [System.IO.Path]::GetExtension($filename)
    $new_ext = ".NA"
    $type = & cmd /u /c  "$script:ffprobe -i `"$filename`" -select_streams v:0 -show_entries stream=codec_name,codec_type -of default=nw=1 -loglevel quiet"
    if($type -match "name=h264")
    {
        $new_ext = ".mp4"
        if($old_ext -ne ".mp4")
        {
            $filename_temp = $filename -replace "$old_ext$","$new_ext"
            Rename-Item -LiteralPath $filename $filename_temp
            write-output "Renamed:"
            write-output "     Old:$filename"
            write-output "     New:$filename_temp"
            return $filename_temp #NewName
        }
    } 
    elseif($type -match "name=prores|name=hevc")
    {
        Write-Output "Conversion NOT DEVELOPED $filename"
        return $filename    
    }
    elseif($type -match "name=gif")
    {
        $new_ext = ".mp4"
        $filename_temp = $filename -replace "$old_ext$","$new_ext"
        $count = 0;
        while($count -lt 100)
        {
            $count++;
            if(($filename -eq $filename_temp) -or (Test-Path $filename_temp))
            {
                $filename_temp = $filename_temp -replace "$new_ext$","_$count$new_ext"
            }
            else
            {
                break
            }
        }
        write-output "Converting:"
        write-output "     Old:$filename"
        write-output "     New:$filename_temp"
        $console = & cmd /u /c  "$script:ffmpeg -i `"$filename`" -hide_banner -loglevel error -movflags faststart -crf 18 -pix_fmt yuv420p -vf  `"scale=trunc(iw/2)*2:trunc(ih/2)*2`" `"$filename_temp`""
        if(Test-Path -LiteralPath "$filename_temp")
        {
            Remove-Item -LiteralPath "$filename"
            return $filename_temp #NewName
        }
    }
    elseif($type -match "name=png")
    {
        $new_ext = ".png"
        if($old_ext -ne ".png")
        {
            $filename_temp = $filename -replace "$old_ext$","$new_ext"
            Rename-Item -LiteralPath $filename $filename_temp
            write-output "Renamed:"
            write-output "     Old:$filename"
            write-output "     New:$filename_temp"
            return $filename_temp #NewName
        }
    }
    elseif($type -match "name=mjpeg")
    {
        
        $new_ext = ".png"
        $filename_temp = $filename -replace "$old_ext$","$new_ext"
        $count = 0;
        while($count -lt 100)
        {
            $count++;
            if(($filename -eq $filename_temp) -or (Test-Path $filename_temp))
            {
                $filename_temp = $filename_temp -replace "$new_ext$","_$count$new_ext"
            }
            else
            {
                break
            }
        }
        write-output "Converting:"
        write-output "     Old:$filename"
        write-output "     New:$filename_temp"
        $console = & cmd /u /c  "$script:ffmpeg -i `"$filename`" -hide_banner -loglevel error -crf 18 `"$filename_temp`""
        if(Test-Path -LiteralPath "$filename_temp")
        {
            Remove-Item -LiteralPath "$filename"
            return $filename_temp #NewName
        }
    }
    return $filename
    write-output
}
##################################################################################
######Get Duration (JOB)##########################################################
function get_duration($filename)
{
    $duration = & cmd /u /c  "$script:ffprobe -i `"$filename`" -show_entries format=duration -v quiet -of csv=`"p=0`""
    return $duration 
}
##################################################################################
######Start Job Sequence##########################################################
job_main   
}#Job
############################################################################################################################################################################################################
#############################################################################################################################################################################################################
    ##################################################################################
    ######Start Job & Display Output##################################################
    $script:load_image_timer = Get-Date
    $first = 1;
    $script:cycler_job = Start-Job -ScriptBlock  $cycler_job_block
    $status_counter = 0;
    Do {[System.Windows.Forms.Application]::DoEvents()
        
        $current_count = $cycler_job.ChildJobs.Output.count;
        $status = $cycler_job.ChildJobs.Output | Select-Object -Skip $status_counter
        if($status_counter -lt $current_count)
        {
            $status_counter = $current_count;
            foreach($output in $status)
            {
                if($output -match "^PB-")
                {
                    $progress_bar.Value = [string]$output.substring(3,[string]$output.length -3);
                }
                elseif($output -match "^PL-")
                {
                    $progress_bar_label.Text = [string]$output.substring(3,[string]$output.length -3);
                }
                else
                {
                    write-host $output
                }
            } 
        }
    } Until (($script:cycler_job.State -ne "Running"))
    write-host Ended
}
################################################################################
######Idle Timer################################################################
Function Idle_Timer
{
    ################################################################################
    ######Track Ticks###############################################################
    --$Script:CountDown

    ################################################################################
    ######Form Reszie Events########################################################
    if(($script:Form_size_w -ne $script:Form.Width) -or ($script:Form_size_h -ne $script:Form.height))
    {
        $Script:Timer.Interval = 500
        $script:locked = 1;
        $script:Form_size_w = $script:Form.Width
        $script:Form_size_h = $script:Form.height
        $script:time_wait = Get-Date
    }
    if($script:locked -eq 1)
    {
        $difference = (Get-Date) - $script:time_wait       
        if(($difference.TotalMilliseconds -gt 300))
        {
            $script:locked = 2;
            if($script:Form.Controls.Count -ge 1)
            {
                for ($i = $script:Form.Controls.Count - 1; $i -ge 0; $i--) 
                {
                    $control = $script:Form.Controls[$i]
                    $script:Form.Controls.Remove($control)
                    $control.Dispose()
                }
            }
            $script:locked = 0;
            $Script:Timer.Interval = $script:settings['CLOCK_SPEED'];
            main
            
        }
    }
}
################################################################################
######Initiate Sequence#########################################################
initial_checks
main
#22 July 2023 (3.0)
#Added Support for some videos not having audio
#Added Support for some videos not being detected

#27 Nov 2024 (3.5)
#Changed Site Download method (Fixed Reddit Block)
#Made Form Resizable
#Check for FFmpeg/FFprobe dialog
#