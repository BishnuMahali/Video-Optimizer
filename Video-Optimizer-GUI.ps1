# Ultimate Video Optimizer Pro (WPF Edition)
# Version: 3.1.1
# MIT License | Copyright (c) 2026 Bishnu Mahali

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# ==========================================
# THEME ENGINE
# ==========================================
function Get-SystemTheme {
    try {
        $reg = Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -ErrorAction SilentlyContinue
        if ($reg.AppsUseLightTheme -eq 0) { return "Dark" }
    } catch {}
    return "Light"
}

$CurrentTheme = Get-SystemTheme
$Theme = if ($CurrentTheme -eq "Dark") {
    @{ WindowBg="#1B1F23"; CardBg="#24292E"; TextMain="#E6EDF3"; TextSub="#8C959F"; Border="#30363D"; InputBg="#0D1117"; Primary="#2DA44E"; Accent="#0969DA"; Shadow="#000000"; ProgressBg="#30363D"; Hover="#3FB950"; Success="#2DA44E"; Error="#CF222E"; Warn="#D4AF37" }
} else {
    @{ WindowBg="#F0F2F5"; CardBg="#FFFFFF"; TextMain="#1B1F23"; TextSub="#57606A"; Border="#D0D7DE"; InputBg="#F6F8FA"; Primary="#2DA44E"; Accent="#0969DA"; Shadow="#D0D7DE"; ProgressBg="#E1E4E8"; Hover="#1A7F37"; Success="#2DA44E"; Error="#CF222E"; Warn="#B38F00" }
}

# ==========================================
# XAML UI DEFINITION
# ==========================================
$xaml_str = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Ultimate Video Optimizer Pro v3.1.1" Height="920" Width="1200" Background="$($Theme.WindowBg)" WindowStartupLocation="CenterScreen">
    <Window.Resources>
        <ControlTemplate x:Key="ComboBoxTemplate" TargetType="ComboBox">
            <Grid>
                <ToggleButton Name="ToggleButton" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" IsChecked="{Binding Path=IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}" ClickMode="Press">
                    <ToggleButton.Template>
                        <ControlTemplate TargetType="ToggleButton">
                            <Border Name="Border" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="4">
                                <Grid HorizontalAlignment="Right" Width="24"><Path Name="Arrow" Fill="{TemplateBinding Foreground}" Data="M 0 0 L 4 4 L 8 0 Z" VerticalAlignment="Center" HorizontalAlignment="Center"/></Grid>
                            </Border>
                        </ControlTemplate>
                    </ToggleButton.Template>
                </ToggleButton>
                <ContentPresenter Name="ContentSite" IsHitTestVisible="False" Content="{TemplateBinding SelectionBoxItem}" ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}" ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}" Margin="10,3,30,3" VerticalAlignment="Center" HorizontalAlignment="Left" />
                <Popup Name="Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}" AllowsTransparency="True" Focusable="False" PopupAnimation="Slide">
                    <Grid Name="DropDown" SnapsToDevicePixels="True" MinWidth="{TemplateBinding ActualWidth}" MaxHeight="{TemplateBinding MaxDropDownHeight}"><Border Name="DropDownBorder" Background="$($Theme.InputBg)" BorderBrush="$($Theme.Border)" BorderThickness="1" CornerRadius="4"><ScrollViewer Margin="0" SnapsToDevicePixels="True"><StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Contained" /></ScrollViewer></Border></Grid>
                </Popup>
            </Grid>
        </ControlTemplate>

        <ControlTemplate x:Key="CheckBoxTemplate" TargetType="CheckBox">
            <StackPanel Orientation="Horizontal">
                <Border Width="18" Height="18" BorderBrush="$($Theme.Border)" BorderThickness="1.5" Background="$($Theme.InputBg)" CornerRadius="3">
                    <Path Name="CheckMark" Fill="$($Theme.Accent)" Data="M 0 5 L 4 9 L 10 0" Visibility="Collapsed" Stroke="$($Theme.Accent)" StrokeThickness="2.5" Margin="2" />
                </Border>
                <ContentPresenter Margin="10,0,0,0" VerticalAlignment="Center" />
            </StackPanel>
            <ControlTemplate.Triggers><Trigger Property="IsChecked" Value="True"><Setter TargetName="CheckMark" Property="Visibility" Value="Visible" /></Trigger></ControlTemplate.Triggers>
        </ControlTemplate>

        <Style TargetType="TextBlock"><Setter Property="Foreground" Value="$($Theme.TextMain)"/></Style>
        <Style TargetType="CheckBox"><Setter Property="Template" Value="{StaticResource CheckBoxTemplate}"/><Setter Property="Foreground" Value="$($Theme.TextMain)"/></Style>
        <Style TargetType="RadioButton"><Setter Property="Foreground" Value="$($Theme.TextMain)"/></Style>
        <Style TargetType="TextBox"><Setter Property="Background" Value="$($Theme.InputBg)"/><Setter Property="Foreground" Value="$($Theme.TextMain)"/><Setter Property="BorderBrush" Value="$($Theme.Border)"/><Setter Property="VerticalContentAlignment" Value="Center"/><Setter Property="Padding" Value="5"/></Style>
        <Style TargetType="ComboBox"><Setter Property="Template" Value="{StaticResource ComboBoxTemplate}" /><Setter Property="Background" Value="$($Theme.InputBg)"/><Setter Property="Foreground" Value="$($Theme.TextMain)"/><Setter Property="BorderBrush" Value="$($Theme.Border)"/><Setter Property="Height" Value="32"/></Style>
        <Style TargetType="ComboBoxItem"><Setter Property="Background" Value="Transparent"/><Setter Property="Foreground" Value="$($Theme.TextMain)"/><Setter Property="Padding" Value="10,6"/><Style.Triggers><Trigger Property="IsHighlighted" Value="True"><Setter Property="Background" Value="$($Theme.Accent)"/><Setter Property="Foreground" Value="White"/></Trigger></Style.Triggers></Style>
        <Style TargetType="DataGrid"><Setter Property="Background" Value="$($Theme.InputBg)"/><Setter Property="BorderBrush" Value="$($Theme.Border)"/><Setter Property="Foreground" Value="$($Theme.TextMain)"/><Setter Property="RowBackground" Value="$($Theme.CardBg)"/><Setter Property="AlternatingRowBackground" Value="$($Theme.InputBg)"/><Setter Property="HorizontalGridLinesBrush" Value="$($Theme.Border)"/><Setter Property="VerticalGridLinesBrush" Value="$($Theme.Border)"/><Setter Property="BorderThickness" Value="1"/><Setter Property="FontSize" Value="13"/><Setter Property="RowHeight" Value="32"/><Setter Property="VirtualizingPanel.IsVirtualizing" Value="True"/><Setter Property="VirtualizingPanel.VirtualizationMode" Value="Recycling"/></Style>
        <Style TargetType="DataGridColumnHeader"><Setter Property="Background" Value="$($Theme.InputBg)"/><Setter Property="Foreground" Value="$($Theme.TextSub)"/><Setter Property="Padding" Value="10,8"/><Setter Property="FontWeight" Value="Bold"/><Setter Property="BorderBrush" Value="$($Theme.Border)"/><Setter Property="BorderThickness" Value="0,0,1,1"/></Style>
        <Style TargetType="DataGridCell"><Setter Property="BorderThickness" Value="0"/><Setter Property="Padding" Value="10,5"/><Style.Triggers><Trigger Property="IsSelected" Value="True"><Setter Property="Background" Value="$($Theme.Accent)"/><Setter Property="Foreground" Value="White"/></Trigger></Style.Triggers></Style>
        <Style x:Key="CardStyle" TargetType="Border"><Setter Property="Background" Value="$($Theme.CardBg)"/><Setter Property="CornerRadius" Value="12"/><Setter Property="Padding" Value="20"/><Setter Property="Margin" Value="0,0,0,20"/><Setter Property="BorderBrush" Value="$($Theme.Border)"/><Setter Property="BorderThickness" Value="1"/><Setter Property="Effect"><Setter.Value><DropShadowEffect BlurRadius="15" Color="$($Theme.Shadow)" ShadowDepth="2" Opacity="0.3"/></Setter.Value></Setter></Style>
        <Style x:Key="PrimaryButtonStyle" TargetType="Button"><Setter Property="Background" Value="$($Theme.Primary)"/><Setter Property="Foreground" Value="White"/><Setter Property="FontWeight" Value="Bold"/><Setter Property="Padding" Value="25,12"/><Setter Property="BorderThickness" Value="0"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Height" Value="45"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border Name="Border" Background="{TemplateBinding Background}" CornerRadius="6"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Border" Property="Background" Value="$($Theme.Hover)"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter TargetName="Border" Property="Background" Value="$($Theme.ProgressBg)"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
        <Style x:Key="SecondaryButtonStyle" TargetType="Button"><Setter Property="Background" Value="$($Theme.InputBg)"/><Setter Property="Foreground" Value="$($Theme.TextMain)"/><Setter Property="BorderBrush" Value="$($Theme.Border)"/><Setter Property="BorderThickness" Value="1"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Height" Value="35"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border Name="Border" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="4"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Border" Property="Background" Value="$($Theme.CardBg)"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
        <Style x:Key="StopButtonStyle" TargetType="Button"><Setter Property="Background" Value="$($Theme.Error)"/><Setter Property="Foreground" Value="White"/><Setter Property="FontWeight" Value="Bold"/><Setter Property="Padding" Value="25,12"/><Setter Property="BorderThickness" Value="0"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Height" Value="45"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border Name="Border" Background="{TemplateBinding Background}" CornerRadius="6"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Border" Property="Opacity" Value="0.8"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter TargetName="Border" Property="Background" Value="$($Theme.ProgressBg)"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
    </Window.Resources>

    <Grid Margin="30">
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
        <StackPanel Grid.Row="0" Margin="0,0,0,25" Orientation="Horizontal"><StackPanel><TextBlock Text="VIDEO OPTIMIZER PRO" FontSize="28" FontWeight="ExtraBold"/><TextBlock Text="Expert FFmpeg workflow with VMAF-based quality targeting" Foreground="$($Theme.TextSub)" FontSize="14"/></StackPanel></StackPanel>
        
        <Grid Grid.Row="1"><Grid.ColumnDefinitions><ColumnDefinition Width="450"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
            <ScrollViewer Grid.Column="0" VerticalScrollBarVisibility="Auto" Margin="0,0,20,0"><StackPanel>
                <Border Style="{StaticResource CardStyle}"><StackPanel><TextBlock Text="1. SOURCE &amp; ENGINE" FontWeight="Bold" Foreground="$($Theme.TextSub)" Margin="0,0,0,8"/><Grid Margin="0,0,0,15"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><TextBox x:Name="txtPath" IsReadOnly="True"/><Button x:Name="btnBrowse" Grid.Column="1" Content="Browse" Width="70" Margin="8,0,0,0" Style="{StaticResource SecondaryButtonStyle}"/></Grid><Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><StackPanel Grid.Column="0" Margin="0,0,5,0"><TextBlock Text="Encoder" FontSize="10" Foreground="$($Theme.TextSub)" Margin="0,0,0,4"/><ComboBox x:Name="comboEncoder"/></StackPanel><StackPanel Grid.Column="1" Margin="5,0,0,0"><TextBlock Text="Container" FontSize="10" Foreground="$($Theme.TextSub)" Margin="0,0,0,4"/><ComboBox x:Name="comboContainer"><ComboBoxItem Content="MP4" IsSelected="True"/><ComboBoxItem Content="MKV"/><ComboBoxItem Content="MOV"/><ComboBoxItem Content="Original"/></ComboBox></StackPanel></Grid><StackPanel Orientation="Horizontal" Margin="0,15,0,0"><CheckBox x:Name="chkQuickTest" Content="Quick Test Mode" IsChecked="True"/><TextBlock Text="Duration:" Margin="20,0,5,0" VerticalAlignment="Center" FontSize="10" Foreground="$($Theme.TextSub)"/><TextBlock x:Name="lblQuickTestVal" Text="25s" VerticalAlignment="Center" FontWeight="Bold" Foreground="$($Theme.Accent)"/></StackPanel><Slider x:Name="sliderQuickTest" Minimum="5" Maximum="60" Value="25" SmallChange="1" LargeChange="5" TickFrequency="1" IsSnapToTickEnabled="True" Margin="0,5,0,0"/><StackPanel Orientation="Horizontal" Margin="0,15,0,0"><CheckBox x:Name="chkRecursive" Content="Recursive Scan" IsChecked="True"/><CheckBox x:Name="chkVmaf" Content="Enable Advanced VMAF" Margin="20,0,0,0" IsChecked="True" Foreground="$($Theme.Accent)" FontWeight="Bold"/></StackPanel></StackPanel></Border>
                <Border Style="{StaticResource CardStyle}" x:Name="cardVmaf"><StackPanel><TextBlock Text="2. ADVANCED VMAF TUNING" FontWeight="Bold" Foreground="$($Theme.TextSub)" Margin="0,0,0,8"/><StackPanel Margin="0,0,0,10"><CheckBox x:Name="chkVmafFallback" Content="Encode with Max VMAF as Fallback" IsChecked="True" Margin="0,0,0,6"/><CheckBox x:Name="chkVmafLadder" Content="Enable Stepping Target" IsChecked="False"/></StackPanel><StackPanel x:Name="panelVmafTarget"><Grid Margin="0,0,0,5"><TextBlock Text="Target Quality (VMAF)" FontSize="10" Foreground="$($Theme.TextSub)"/><TextBlock x:Name="lblVmafTarget" Text="93" HorizontalAlignment="Right" FontWeight="Bold" Foreground="$($Theme.Accent)"/></Grid><Slider x:Name="sliderVmaf" Minimum="70" Maximum="100" Value="93" Margin="0,0,0,15"/></StackPanel><StackPanel x:Name="panelVmafLadder" Visibility="Collapsed" Margin="0,0,0,15"><TextBlock Text="VMAF Target Ladder (Space/Comma Separated)" FontSize="10" Foreground="$($Theme.TextSub)" Margin="0,0,0,4"/><TextBox x:Name="txtVmafLadder" Text="93" Height="30" Margin="0,0,0,5"/></StackPanel><StackPanel Margin="0,0,0,15"><Grid Margin="0,0,0,5"><TextBlock Text="Minimum VMAF Ceiling" FontSize="10" Foreground="$($Theme.TextSub)"/><TextBlock x:Name="lblVmafCeiling" Text="85" HorizontalAlignment="Right" FontWeight="Bold" Foreground="$($Theme.Accent)"/></Grid><Slider x:Name="sliderVmafCeiling" Minimum="0" Maximum="100" Value="85"/></StackPanel><Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><StackPanel Grid.Column="0" Margin="0,0,5,0"><TextBlock Text="Samples" FontSize="10" Foreground="$($Theme.TextSub)" Margin="0,0,0,4"/><ComboBox x:Name="comboSamples"><ComboBoxItem Content="1 Sample"/><ComboBoxItem Content="3 Samples (Balanced)" IsSelected="True"/><ComboBoxItem Content="5 Samples"/></ComboBox></StackPanel><StackPanel Grid.Column="1" Margin="5,0,0,0"><TextBlock Text="Probe Duration" FontSize="10" Foreground="$($Theme.TextSub)" Margin="0,0,0,4"/><ComboBox x:Name="comboProbeDur"><ComboBoxItem Content="3 Seconds"/><ComboBoxItem Content="5 Seconds" IsSelected="True"/><ComboBoxItem Content="10 Seconds"/></ComboBox></StackPanel></Grid></StackPanel></Border>
                <Border Style="{StaticResource CardStyle}" x:Name="cardManual" Visibility="Collapsed"><StackPanel><TextBlock Text="2. MANUAL QUALITY LADDER" FontWeight="Bold" Foreground="$($Theme.TextSub)" Margin="0,0,0,8"/><TextBox x:Name="txtQualityLadder" Text="23,26,29" Height="30"/><TextBlock Text="Speed Preset" FontWeight="Bold" Foreground="$($Theme.TextSub)" Margin="0,15,0,8"/><ComboBox x:Name="comboPreset"/></StackPanel></Border>
                <Border Style="{StaticResource CardStyle}"><StackPanel><TextBlock Text="3. AUDIO &amp; POST-PROCESS" FontWeight="Bold" Foreground="$($Theme.TextSub)" Margin="0,0,0,8"/><ComboBox x:Name="comboAudio" Margin="0,0,0,15"><ComboBoxItem Content="Copy (Original)" IsSelected="True"/><ComboBoxItem Content="AAC (128k)"/><ComboBoxItem Content="AAC (192k)"/></ComboBox><TextBlock Text="On Failure" FontWeight="Bold" Foreground="$($Theme.TextSub)" Margin="0,0,0,8"/><ComboBox x:Name="comboOnFail"><ComboBoxItem Content="Move to 'Unoptimizable'" IsSelected="True"/><ComboBoxItem Content="Delete File"/><ComboBoxItem Content="Ignore (Keep Original)"/></ComboBox></StackPanel></Border>
                <Border Style="{StaticResource CardStyle}"><StackPanel><TextBlock Text="4. SESSION OPTIONS" FontWeight="Bold" Foreground="$($Theme.TextSub)" Margin="0,0,0,8"/><CheckBox x:Name="chkResume" Content="Enable Resume Functionality" IsChecked="True" Margin="0,0,0,8"/><CheckBox x:Name="chkCache" Content="Enable Cache for Faster Processing" IsChecked="True" Margin="0,0,0,8"/><CheckBox x:Name="chkLog" Content="Enable Log" IsChecked="True"/></StackPanel></Border>
            </StackPanel></ScrollViewer>
            <Grid Grid.Column="1"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="220"/></Grid.RowDefinitions>
                <UniformGrid Grid.Row="0" Columns="4" Margin="0,0,0,20">
                    <Border Style="{StaticResource CardStyle}" Margin="0,0,8,0" Padding="12"><StackPanel HorizontalAlignment="Center"><TextBlock Text="FILES" FontSize="9" Foreground="$($Theme.TextSub)" FontWeight="Bold" HorizontalAlignment="Center"/><TextBlock x:Name="statFiles" Text="0" FontSize="20" FontWeight="Bold"/></StackPanel></Border>
                    <Border Style="{StaticResource CardStyle}" Margin="4,0,4,0" Padding="12"><StackPanel HorizontalAlignment="Center"><TextBlock Text="SAVED" FontSize="9" Foreground="$($Theme.Success)" FontWeight="Bold" HorizontalAlignment="Center"/><TextBlock x:Name="statSaved" Text="0 MB" FontSize="20" FontWeight="Bold" Foreground="$($Theme.Success)"/></StackPanel></Border>
                    <Border Style="{StaticResource CardStyle}" Margin="4,0,4,0" Padding="12"><StackPanel HorizontalAlignment="Center"><TextBlock Text="EFFICIENCY" FontSize="9" Foreground="$($Theme.Accent)" FontWeight="Bold" HorizontalAlignment="Center"/><TextBlock x:Name="statEff" Text="0%" FontSize="20" FontWeight="Bold" Foreground="$($Theme.Accent)"/></StackPanel></Border>
                    <Border Style="{StaticResource CardStyle}" Margin="8,0,0,0" Padding="12"><StackPanel HorizontalAlignment="Center"><TextBlock Text="VMAF" FontSize="9" Foreground="$($Theme.TextSub)" FontWeight="Bold" HorizontalAlignment="Center"/><TextBlock x:Name="statVmaf" Text="---" FontSize="20" FontWeight="Bold"/></StackPanel></Border>
                </UniformGrid>
                <Border Grid.Row="1" Style="{StaticResource CardStyle}" Padding="0"><DataGrid x:Name="dgFiles" AutoGenerateColumns="False" IsReadOnly="True" BorderThickness="0" SelectionMode="Single" CanUserAddRows="False"><DataGrid.Columns><DataGridTextColumn Header="Filename" Binding="{Binding Name}" Width="*"/><DataGridTextColumn Header="Old Size" Binding="{Binding OldSize}" Width="80"/><DataGridTextColumn Header="New Size" Binding="{Binding NewSize}" Width="80"/><DataGridTextColumn Header="Saving" Binding="{Binding Saving}" Width="70"><DataGridTextColumn.ElementStyle><Style TargetType="TextBlock"><Setter Property="Foreground" Value="$($Theme.Success)"/><Setter Property="FontWeight" Value="Bold"/><Setter Property="VerticalAlignment" Value="Center"/><Setter Property="HorizontalAlignment" Value="Center"/></Style></DataGridTextColumn.ElementStyle></DataGridTextColumn><DataGridTextColumn Header="Status" Binding="{Binding Status}" Width="150"><DataGridTextColumn.ElementStyle><Style TargetType="TextBlock"><Setter Property="FontWeight" Value="SemiBold"/><Setter Property="VerticalAlignment" Value="Center"/><Style.Triggers><DataTrigger Binding="{Binding Status}" Value="Done"><Setter Property="Foreground" Value="$($Theme.Success)"/></DataTrigger><DataTrigger Binding="{Binding Status}" Value="In Progress"><Setter Property="Foreground" Value="$($Theme.Accent)"/></DataTrigger><DataTrigger Binding="{Binding Status}" Value="Skipped (Quick Test)"><Setter Property="Foreground" Value="$($Theme.Warn)"/></DataTrigger><DataTrigger Binding="{Binding Status}" Value="Already Efficient"><Setter Property="Foreground" Value="$($Theme.TextSub)"/></DataTrigger><DataTrigger Binding="{Binding Status}" Value="Cached Skip"><Setter Property="Foreground" Value="$($Theme.TextSub)"/></DataTrigger><DataTrigger Binding="{Binding Status}" Value="Stopped"><Setter Property="Foreground" Value="$($Theme.TextSub)"/></DataTrigger><DataTrigger Binding="{Binding Status}" Value="Failed"><Setter Property="Foreground" Value="$($Theme.Error)"/></DataTrigger><DataTrigger Binding="{Binding Status}" Value="Larger than Source"><Setter Property="Foreground" Value="$($Theme.Error)"/></DataTrigger><DataTrigger Binding="{Binding Status}" Value="Max VMAF &lt; Min VMAF"><Setter Property="Foreground" Value="$($Theme.Error)"/></DataTrigger><DataTrigger Binding="{Binding Status}" Value="Path Error"><Setter Property="Foreground" Value="$($Theme.Error)"/></DataTrigger></Style.Triggers></Style></DataGridTextColumn.ElementStyle></DataGridTextColumn></DataGrid.Columns></DataGrid></Border>
                <Border Grid.Row="2" Background="$($Theme.InputBg)" CornerRadius="8" Padding="12" Margin="0,20,0,0" BorderBrush="$($Theme.Border)" BorderThickness="1"><TextBox x:Name="txtLogs" Background="Transparent" Foreground="$($Theme.TextMain)" BorderThickness="0" IsReadOnly="True" VerticalScrollBarVisibility="Auto" TextWrapping="Wrap" FontFamily="Consolas" FontSize="11"/></Border>
            </Grid>
        </Grid>
        <Grid Grid.Row="2" Margin="0,25,0,0">
            <StackPanel Orientation="Horizontal" VerticalAlignment="Center"><ProgressBar x:Name="progressMain" Width="400" Height="6" Minimum="0" Maximum="100" Value="0" Margin="0,0,25,0" Background="$($Theme.ProgressBg)" Foreground="$($Theme.Accent)" BorderThickness="0"/><TextBlock x:Name="lblStatus" Text="Ready" Foreground="$($Theme.TextSub)" FontWeight="SemiBold"/></StackPanel>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                <Button x:Name="btnStop" Content="STOP" Style="{StaticResource StopButtonStyle}" Width="100" Margin="0,0,15,0" Visibility="Collapsed"/>
                <Button x:Name="btnStart" Content="START PRO OPTIMIZATION" Style="{StaticResource PrimaryButtonStyle}" Width="280"/>
            </StackPanel>
        </Grid>
    </Grid>
</Window>
"@

$window = [Windows.Markup.XamlReader]::Parse($xaml_str)
if ($null -eq $window) { throw "WPF Window failed to load!" }

$txtPath=$window.FindName("txtPath"); $btnBrowse=$window.FindName("btnBrowse"); $chkRecursive=$window.FindName("chkRecursive"); $chkVmaf=$window.FindName("chkVmaf"); $cardVmaf=$window.FindName("cardVmaf"); $cardManual=$window.FindName("cardManual"); $comboEncoder=$window.FindName("comboEncoder"); $comboContainer=$window.FindName("comboContainer"); $sliderVmaf=$window.FindName("sliderVmaf"); $lblVmafTarget=$window.FindName("lblVmafTarget"); $comboSamples=$window.FindName("comboSamples"); $comboProbeDur=$window.FindName("comboProbeDur"); $txtQualityLadder=$window.FindName("txtQualityLadder"); $comboPreset=$window.FindName("comboPreset"); $comboAudio=$window.FindName("comboAudio"); $comboOnFail=$window.FindName("comboOnFail"); $chkResume=$window.FindName("chkResume"); $chkCache=$window.FindName("chkCache"); $chkLog=$window.FindName("chkLog"); $statFiles=$window.FindName("statFiles"); $statSaved=$window.FindName("statSaved"); $statEff=$window.FindName("statEff"); $statVmaf=$window.FindName("statVmaf"); $dgFiles=$window.FindName("dgFiles"); $txtLogs=$window.FindName("txtLogs"); $progressMain=$window.FindName("progressMain"); $lblStatus=$window.FindName("lblStatus"); $btnStart=$window.FindName("btnStart"); $btnStop=$window.FindName("btnStop")
$chkVmafFallback=$window.FindName("chkVmafFallback"); $chkVmafLadder=$window.FindName("chkVmafLadder"); $panelVmafTarget=$window.FindName("panelVmafTarget"); $panelVmafLadder=$window.FindName("panelVmafLadder"); $txtVmafLadder=$window.FindName("txtVmafLadder"); $sliderVmafCeiling=$window.FindName("sliderVmafCeiling"); $lblVmafCeiling=$window.FindName("lblVmafCeiling")
$chkQuickTest=$window.FindName("chkQuickTest"); $sliderQuickTest=$window.FindName("sliderQuickTest"); $lblQuickTestVal=$window.FindName("lblQuickTestVal")

$global:logEnabled=$false; $global:logFilePath=""; $global:videoFiles=@(); $global:stopRequested=$false; $global:StopSignal = New-Object 'bool[]' 1; $global:StopSignal[0] = $false
$knownVideoExtensions = @('.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.ts', '.vob', '.m2ts', '.mpeg', '.mpg')

$availableEncoders = @(
    @{ ID="1"; Name="NVIDIA AV1 (NVENC)"; Codec="av1_nvenc"; Mode="cq"; Rank=1; Supported=$false }
    @{ ID="2"; Name="NVIDIA HEVC (NVENC)"; Codec="hevc_nvenc"; Mode="cq"; Rank=2; Supported=$false }
    @{ ID="3"; Name="NVIDIA H.264 (NVENC)"; Codec="h264_nvenc"; Mode="cq"; Rank=3; Supported=$false }
    @{ ID="4"; Name="AMD AV1 (AMF)"; Codec="av1_amf"; Mode="qp"; Rank=4; Supported=$false }
    @{ ID="5"; Name="AMD HEVC (AMF)"; Codec="hevc_amf"; Mode="qp"; Rank=5; Supported=$false }
    @{ ID="6"; Name="AMD H.264 (AMF)"; Codec="h264_amf"; Mode="qp"; Rank=6; Supported=$false }
    @{ ID="7"; Name="Intel AV1 (QSV)"; Codec="av1_qsv"; Mode="global_quality"; Rank=7; Supported=$false }
    @{ ID="8"; Name="Intel HEVC (QSV)"; Codec="hevc_qsv"; Mode="global_quality"; Rank=8; Supported=$false }
    @{ ID="9"; Name="Intel H.264 (QSV)"; Codec="h264_qsv"; Mode="global_quality"; Rank=9; Supported=$false }
    @{ ID="10"; Name="AV1 SVT (CPU)"; Codec="libsvtav1"; Mode="crf"; Rank=10; Supported=$true }
    @{ ID="11"; Name="HEVC (CPU - libx265)"; Codec="libx265"; Mode="crf"; Rank=11; Supported=$true }
    @{ ID="12"; Name="H.264 (CPU - libx264)"; Codec="libx264"; Mode="crf"; Rank=12; Supported=$true }
)

$presetOptions = @{ "nvenc"=@("p1","p2","p3","p4","p5","p6","p7"); "libsvtav1"=@("0","1","2","3","4","5","6","7","8","9","10","11","12","13"); "cpu"=@("ultrafast","superfast","veryfast","faster","fast","medium","slow","slower","veryslow","placebo"); "qsv"=@("veryfast","faster","fast","balanced","slow","slower","veryslow"); "amf"=@("speed","balanced","quality") }

function Add-Log { param([string]$msg) $window.Dispatcher.Invoke({ $ts="$(Get-Date -Format 'HH:mm:ss') - $msg"; $txtLogs.AppendText("$ts`r`n"); $txtLogs.ScrollToEnd(); if ($global:logEnabled -and $global:logFilePath) { try { Add-Content -Path $global:logFilePath -Value $ts -ErrorAction SilentlyContinue } catch {} } }) }
function Format-Bytes { param([long]$Bytes) if ($Bytes -ge 1GB) { return "$([math]::Round($Bytes / 1GB, 2)) GB" }; if ($Bytes -ge 1MB) { return "$([math]::Round($Bytes / 1MB, 2)) MB" }; if ($Bytes -ge 1KB) { return "$([math]::Round($Bytes / 1KB, 2)) KB" }; return "$Bytes B" }

function Cleanup-Orphans {
    try {
        $path = $txtPath.Text
        if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path)) { return }
        $tempPath = Join-Path $path ".Video Optimizer" | Join-Path -ChildPath "temp"
        if (Test-Path $tempPath) {
            Add-Log "[INFO] Cleaning up orphaned temporary files..."
            Get-ChildItem -Path $tempPath -File | ForEach-Object {
                try { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue } catch {}
            }
        }
    } catch {
        Add-Log "[WARN] Failed to clean up temp folder: $_"
    }
}

function Update-PresetList {
    $sel=$comboEncoder.SelectedItem; if (-not $sel) { return }; $enc=$sel.Tag; $codec=$enc.Codec
    $list = if ($codec -match "nvenc") { $presetOptions["nvenc"] } elseif ($codec -match "libsvtav1") { $presetOptions["libsvtav1"] } elseif ($codec -match "libx265|libx264") { $presetOptions["cpu"] } elseif ($codec -match "qsv") { $presetOptions["qsv"] } elseif ($codec -match "amf") { $presetOptions["amf"] } else { @("none") }
    $comboPreset.Items.Clear(); foreach ($p in $list) { $comboPreset.Items.Add($p) }
    if ($codec -match "nvenc") { $comboPreset.SelectedItem="p5" } elseif ($codec -match "libsvtav1") { $comboPreset.SelectedItem="6" } elseif ($codec -match "libx265|libx264") { $comboPreset.SelectedItem="slow" } else { $comboPreset.SelectedIndex=0 }
}

function Scan-Files {
    $path=$txtPath.Text; if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path)) { return }
    $files=Get-ChildItem -LiteralPath $path -File -Recurse:$chkRecursive.IsChecked | Where-Object { $knownVideoExtensions -contains $_.Extension.ToLower() }
    $global:videoFiles = $files | ForEach-Object { [PSCustomObject]@{ Name=$_.Name; FullName=$_.FullName; Directory=$_.DirectoryName; Extension=$_.Extension; OldSize=(Format-Bytes $_.Length); OldSizeBytes=$_.Length; NewSize="---"; Saving="---"; Status="Queued" } }
    $dgFiles.ItemsSource=[System.Collections.ObjectModel.ObservableCollection[PSCustomObject]]$global:videoFiles; $statFiles.Text=$global:videoFiles.Count
}

$txtPath.Text=$PWD.Path; Add-Log "Detecting hardware encoders..."
$ffmpegEncoders=(ffmpeg -encoders 2>&1 | Out-String); $comboEncoder.Items.Clear()
foreach ($enc in $availableEncoders) {
    $color="#6E7781"; $status="Not Found"
    if ($enc.Codec -match "libsvtav1|libx265|libx264") { $enc.Supported=$true; $color="#2DA44E"; $status="Software (Confirmed)" }
    elseif ($ffmpegEncoders -match "\b$($enc.Codec)\b") {
        $dummy=@("-v","error","-f","lavfi","-i","color=black:s=1280x720:r=24","-pix_fmt","yuv420p","-vframes","1","-c:v",$enc.Codec,"-f","null","-")
        $null = & ffmpeg @dummy 2>&1
        if ($LASTEXITCODE -eq 0) { $enc.Supported=$true; $color="#2DA44E"; $status="Hardware (Confirmed)" } else { $enc.Supported=$false; $color="#D29922"; $status="Hardware (Init failed)" }
    }
    $item=New-Object System.Windows.Controls.ComboBoxItem; $stack=New-Object System.Windows.Controls.StackPanel; $stack.Orientation="Horizontal"
    $circle=New-Object System.Windows.Controls.Border; $circle.Width=10; $circle.Height=10; $circle.CornerRadius=5; $circle.Margin="0,0,10,0"; $circle.Background=[System.Windows.Media.BrushConverter]::new().ConvertFromString($color)
    $text=New-Object System.Windows.Controls.TextBlock; $text.Text=$enc.Name; $text.Foreground=[System.Windows.Media.BrushConverter]::new().ConvertFromString($Theme.TextMain)
    $stack.Children.Add($circle); $stack.Children.Add($text); $item.Content=$stack; $item.Tag=$enc; $item.ToolTip=$status; $comboEncoder.Items.Add($item)
}
$bestMatch=$null; foreach($item in $comboEncoder.Items) { if ($item.ToolTip -match "Confirmed" -and $item.Tag.Codec -match "nvenc|amf|qsv") { if ($bestMatch -eq $null -or $item.Tag.Rank -lt $bestMatch.Tag.Rank) { $bestMatch=$item } } }
if ($bestMatch) { $comboEncoder.SelectedItem=$bestMatch } else { $comboEncoder.SelectedIndex=0 }
Update-PresetList; Scan-Files; Cleanup-Orphans

$btnBrowse.Add_Click({ Add-Type -AssemblyName System.Windows.Forms; $dialog=New-Object System.Windows.Forms.FolderBrowserDialog; $dialog.SelectedPath=$txtPath.Text; if ($dialog.ShowDialog() -eq "OK") { $txtPath.Text=$dialog.SelectedPath; Scan-Files; Cleanup-Orphans } })
$chkResume.Add_Click({ if ($chkResume.IsChecked) { $chkCache.IsChecked=$true } }); $chkCache.Add_Click({ if (-not $chkCache.IsChecked) { $chkResume.IsChecked=$false } })
$chkVmaf.Add_Click({ if ($chkVmaf.IsChecked) { $cardVmaf.Visibility="Visible"; $cardManual.Visibility="Collapsed" } else { $cardVmaf.Visibility="Collapsed"; $cardManual.Visibility="Visible" } })
$sliderVmaf.Add_ValueChanged({
    $lblVmafTarget.Text=[int]$sliderVmaf.Value
    if ($txtVmafLadder.Text -notmatch ",") {
        $txtVmafLadder.Text = [string][int]$sliderVmaf.Value
    }
})
$sliderVmafCeiling.Add_ValueChanged({
    $lblVmafCeiling.Text=[int]$sliderVmafCeiling.Value
})
$chkVmafLadder.Add_Click({
    if ($chkVmafLadder.IsChecked) {
        $panelVmafTarget.Visibility = "Collapsed"
        $panelVmafLadder.Visibility = "Visible"
    } else {
        $panelVmafTarget.Visibility = "Visible"
        $panelVmafLadder.Visibility = "Collapsed"
    }
})
$chkQuickTest.Add_Click({
    if ($chkQuickTest.IsChecked) {
        $sliderQuickTest.Visibility = "Visible"
    } else {
        $sliderQuickTest.Visibility = "Collapsed"
    }
})
$sliderQuickTest.Add_ValueChanged({
    $lblQuickTestVal.Text = "$([int]$sliderQuickTest.Value)s"
})
$comboEncoder.Add_SelectionChanged({ Update-PresetList })

$btnStop.Add_Click({ $global:stopRequested=$true; $btnStop.IsEnabled=$false; Add-Log "[STOP] Cancellation requested. Cleaning up current file..." })

$btnStart.Add_Click({
    if ($global:videoFiles.Count -eq 0) { return }; $btnStart.IsEnabled=$false; $btnBrowse.IsEnabled=$false; $btnStop.Visibility="Visible"; $btnStop.IsEnabled=$true; $global:stopRequested=$false; $selEnc=$comboEncoder.SelectedItem.Tag; $global:logEnabled=$chkLog.IsChecked
    $workDir=Join-Path $txtPath.Text ".Video Optimizer"; if ($chkCache.IsChecked -or $chkLog.IsChecked) { if (-not (Test-Path $workDir)) { $hd=New-Item -ItemType Directory -Path $workDir -Force; $hd.Attributes="Directory","Hidden" } }
    $cacheFile=Join-Path $workDir "Cache.json"; $global:logFilePath=Join-Path $workDir "Log.txt"
    $cache=@{}; if ($chkResume.IsChecked -and (Test-Path $cacheFile)) { try { $json=Get-Content $cacheFile -Raw | ConvertFrom-Json; foreach($e in $json){ if($e.Path){$cache[$e.Path.ToLowerInvariant()]=$e} } } catch {} }
    
    $vmafSamples = switch($comboSamples.SelectedIndex){0{1};2{5};default{3}}
    $vmafDur = switch($comboProbeDur.SelectedIndex){0{3};2{10};default{5}}
    $vmafFallback = [bool]$chkVmafFallback.IsChecked
    $vmafCeiling = [double]$sliderVmafCeiling.Value
    
    if ($chkVmafLadder.IsChecked) {
        $q_part = "vmaf=$($txtVmafLadder.Text)|samples=$vmafSamples|dur=$vmafDur|fallback=$vmafFallback|ceiling=$vmafCeiling"
    } else {
        $q_part = "vmaf_target=$([int]$sliderVmaf.Value)|samples=$vmafSamples|dur=$vmafDur|fallback=$vmafFallback|ceiling=$vmafCeiling"
    }
    $settingsKey = "$($selEnc.Codec)|$($comboPreset.SelectedItem)|$q_part|$($comboAudio.Text)"
    
    $vmafLadder = if ($chkVmafLadder.IsChecked) {
        $txtVmafLadder.Text.Replace(',', ' ').Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { if ([int]::TryParse($_, [ref]0)) { [int]$_ } } | Sort-Object -Descending
    } else {
        @([int]$sliderVmaf.Value)
    }
    
    $tempDir = Join-Path $workDir "temp"
    if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir -Force | Out-Null }
    
    $config=@{
        Encoder=$selEnc.Codec
        Mode=$selEnc.Mode
        VmafEnabled=$chkVmaf.IsChecked
        VmafTarget=[int]$sliderVmaf.Value
        VmafSamples=$vmafSamples
        VmafDur=$vmafDur
        QualityLadder=$txtQualityLadder.Text -split ','
        Preset=$comboPreset.SelectedItem
        Container=switch($comboContainer.SelectedIndex){1{".mkv"};2{".mov"};3{"Original"};default{".mp4"}}
        Audio=switch($comboAudio.SelectedIndex){1{"aac 128k"};2{"aac 192k"};default{"copy"}}
        OnFail=switch($comboOnFail.SelectedIndex){1{"Delete"};2{"Ignore"};default{"Move"}}
        CacheEnabled=$chkCache.IsChecked
        CacheFile=$cacheFile
        Cache=$cache
        SettingsKey=$settingsKey
        ResumeEnabled=$chkResume.IsChecked
        VmafMinCeiling=$vmafCeiling
        VmafFallbackEnabled=$vmafFallback
        VmafLadderEnabled=[bool]$chkVmafLadder.IsChecked
        VmafLadder=$vmafLadder
        QuickTestEnabled=[bool]$chkQuickTest.IsChecked
        QuickTestDuration=[int]$sliderQuickTest.Value
        TempDir=$tempDir
    }
    $global:processedCount=0; $global:totalSavedBytes=0; $global:totalOriginalBytes=0
    $global:StopSignal[0] = $false
    
    $job={ param($files, $config, $stopSignal)
        try {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            
            function Run-FFmpegWithProgress {
                param(
                    [string[]]$ffArgs,
                    [int]$fileIndex,
                    [int]$totalFiles,
                    [double]$fileDuration
                )
                try {
                    $p = New-Object System.Diagnostics.Process
                    $p.StartInfo.FileName = "ffmpeg"
                    $argsWithProgress = @("-progress", "pipe:1") + $ffArgs
                    $p.StartInfo.Arguments = ($argsWithProgress -join " ")
                    $p.StartInfo.UseShellExecute = $false
                    $p.StartInfo.CreateNoWindow = $true
                    $p.StartInfo.RedirectStandardOutput = $true
                    $p.StartInfo.RedirectStandardError = $true
                    
                    $p.Start() | Out-Null
                    
                    $fps = "---"
                    $speed = "---"
                    $reader = $p.StandardOutput
                    while (!$reader.EndOfStream -or !$p.HasExited) {
                        if ($stopSignal[0]) {
                            try { $p.Kill() } catch {}
                            return $false
                        }
                        $line = $reader.ReadLine()
                        if ($null -ne $line) {
                            if ($line -match "^fps=(.*)") {
                                $fps = $matches[1].Trim()
                            }
                            elseif ($line -match "^speed=(.*)") {
                                $speed = $matches[1].Trim()
                            }
                            elseif ($line -match "^out_time_us=(\d+)") {
                                $us = [double]$matches[1]
                                $currentSec = $us / 1000000.0
                                if ($fileDuration -gt 0) {
                                    $pct = $currentSec / $fileDuration
                                    if ($pct -lt 0.0) { $pct = 0.0 }
                                    if ($pct -gt 1.0) { $pct = 1.0 }
                                    $overallPercent = (($fileIndex + $pct) / $totalFiles) * 100
                                    
                                    $pctFormatted = [math]::Round($pct * 100, 1)
                                    $secFormatted = [math]::Round($currentSec, 1)
                                    $durFormatted = [math]::Round($fileDuration, 1)
                                    
                                    $etaStr = "---"
                                    try {
                                        $speedClean = $speed.Replace('x', '').Trim()
                                        if ([double]::TryParse($speedClean, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$speedVal)) {
                                            if ($speedVal -gt 0) {
                                                $etaSec = [int](($fileDuration - $currentSec) / $speedVal)
                                                if ($etaSec -gt 60) {
                                                    $etaStr = "$([int]($etaSec / 60))m $($etaSec % 60)s"
                                                } else {
                                                    $etaStr = "${etaSec}s"
                                                }
                                            }
                                        }
                                    } catch {}
                                    
                                    Write-Output @{
                                        Type = "Progress"
                                        Msg = "Processing: File $($fileIndex + 1)/$totalFiles - ${pctFormatted}% | Speed: $speed | FPS: $fps | ETA: $etaStr"
                                        Pct = $overallPercent
                                    }
                                }
                            }
                        } else {
                            Start-Sleep -Milliseconds 10
                        }
                    }
                    
                    $p.WaitForExit()
                    return ($p.ExitCode -eq 0)
                } catch {
                    Write-Output @{ Type="Log"; Msg="[ERROR] FFmpeg process failed: $_" }
                    return $false
                }
            }

            Write-Output @{ Type="Log"; Msg=">>> BACKEND PROCESS STARTED: $($files.Count) files" }
        foreach ($f in $files) {
            if ($stopSignal[0]) { Write-Output @{ Type="Log"; Msg="[STOP] Process aborted by user." }; break }
            $idx = [array]::IndexOf($files, $f)
            Write-Output @{ Index=$idx; Type="Update"; Status="In Progress" }
            Write-Output @{ Type="Log"; Msg="--- Processing: $($f.Name) ---" }
            
            $key=$f.FullName.ToLowerInvariant(); $sig="$($f.OldSizeBytes)|$((Get-Item -LiteralPath $f.FullName).LastWriteTimeUtc.Ticks)"
            if ($config.ResumeEnabled -and $config.Cache.ContainsKey($key)) { 
                $cached=$config.Cache[$key]
                if ($cached.Signature -eq $sig -and $cached.SettingsKey -eq $config.SettingsKey) { 
                    Write-Output @{ Type="Log"; Msg="[SKIP] Found in cache with matching settings." }
                    Write-Output @{ Index=$idx; Success=$false; Msg="Cached Skip"; Vmaf="---"; Total=$files.Count; File=$f.Name; Type="Result" }; continue 
                } 
            }
            
            $uid = [guid]::NewGuid().ToString().Substring(0,8)
            $res=@{ Success=$false; NewSize=0; Msg="Failed"; FinalVmaf="---" }
            $dir=$f.Directory
            $ext=if($config.Container -eq "Original"){$f.Extension}else{$config.Container}
            $tempOut = Join-Path $config.TempDir "$($f.Name)_$uid.tmp$ext"
            $finalOut=Join-Path $dir ($f.Name.Replace($f.Extension,"")+"_opt"+$ext)
            
            if (![string]::IsNullOrWhiteSpace($f.FullName)) {
                $durIn = (& ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$($f.FullName)" 2>$null | Out-String).Trim()
                if($durIn -match "^\d+(\.\d+)?$"){ $duration=[double]$durIn } else { $duration=60 }
                
                # Quick Test Mode Setup
                $quickTest = $config.QuickTestEnabled
                $quickTestDur = $config.QuickTestDuration
                
                # Enforce minimum duration dynamically based on VMAF settings
                $vmafEnabled = $config.VmafEnabled
                $vmafSamples = if ($config.VmafSamples) { [int]$config.VmafSamples } else { 3 }
                $vmafDur = if ($config.VmafDur) { [int]$config.VmafDur } else { 5 }
                $minNeeded = if ($vmafEnabled) { $vmafSamples * $vmafDur } else { 5 }
                if ($quickTest -and $quickTestDur -lt $minNeeded) {
                    $quickTestDur = $minNeeded
                }
                
                $isClipExtracted = $false
                $clipPath = $null
                
                if ($quickTest -and $duration -and $duration -gt ($quickTestDur * 2)) {
                    Write-Output @{ Type="Log"; Msg="[QUICK TEST] Preparing $($quickTestDur)s representative clip for '$($f.Name)'..." }
                    $startTime = [math]::max(0.0, $duration * 0.1)
                    
                    $clipPath = Join-Path $config.TempDir "clip_src_${uid}$($f.Extension)"
                    
                    $hwDecodeArgs = @()
                    if ($config.Encoder -match "nvenc") { $hwDecodeArgs = @("-hwaccel", "cuda") }
                    elseif ($config.Encoder -match "qsv") { $hwDecodeArgs = @("-hwaccel", "qsv") }
                    elseif ($config.Encoder -match "amf") { $hwDecodeArgs = @("-hwaccel", "d3d11va") }
                    
                    $extractArgs = @("-y", "-loglevel", "error") + $hwDecodeArgs + @("-ss", "$startTime", "-t", "$quickTestDur", "-i", "$($f.FullName)", "-c", "copy", "$clipPath")
                    
                    $p = Start-Process -FilePath "ffmpeg" -ArgumentList $extractArgs -NoNewWindow -Wait -PassThru
                    if ($p.ExitCode -eq 0 -and (Test-Path $clipPath)) {
                        $isClipExtracted = $true
                        $clipSize = (Get-Item $clipPath).Length
                        $clipSizeDisplay = if ($clipSize -gt 1MB) { "$((($clipSize)/1MB).ToString('F2')) MB" } else { "$((($clipSize)/1KB).ToString('F2')) KB" }
                        Write-Output @{ Type="Log"; Msg="[QUICK TEST] Clip extracted for '$($f.Name)': $(Split-Path $clipPath -Leaf) ($clipSizeDisplay)" }
                    } else {
                        Write-Output @{ Type="Log"; Msg="[WARN] Extracted clip is empty or stream copy failed. Falling back to full video optimization." }
                        if (Test-Path $clipPath) { Remove-Item $clipPath -Force }
                        $clipPath = $null
                    }
                }
                
                $testPath = if ($isClipExtracted) { $clipPath } else { $f.FullName }
                $testDuration = if ($isClipExtracted) { $quickTestDur } else { $duration }

                # Audio codec check
                $source_audio = (& ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$($f.FullName)" 2>$null | Out-String).Trim().ToLower()
                $target_audio_args = @()
                if ($config.Audio -eq "copy") {
                    $incompatible = $false
                    if ($config.Container -eq ".mp4" -and -not ($source_audio -match "aac|mp3|opus|ac3|eac3|mp2|mp1")) { $incompatible = $true }
                    elseif ($config.Container -eq ".mov" -and -not ($source_audio -match "aac|mp3|ac3|eac3|alac|pcm")) { $incompatible = $true }
                    
                    if ($incompatible) {
                        Write-Output @{ Type="Log"; Msg="[WARN] Audio ($source_audio) incompatible with $($config.Container). Encoding to AAC." }
                        $target_audio_args = @("-c:a", "aac", "-b:a", "128k")
                    } else {
                        $target_audio_args = @("-c:a", "copy")
                    }
                } else {
                    $parts = $config.Audio.Split(" ")
                    $target_audio_args = @("-c:a", $parts[0], "-b:a", $parts[1])
                }
                
                if ($config.VmafEnabled) {
                    $vmafLadder = $config.VmafLadder
                    $maxAchievableVmaf = 100.0
                    $maxVmafCq = $null
                    $minCeiling = $config.VmafMinCeiling
                    
                    # Load cached ceiling if available
                    $probeKey = "codec=$($config.Encoder)|preset=$($config.Preset)|samples=$($config.VmafSamples)|dur=$($config.VmafDur)"
                    if ($config.CacheEnabled -and $config.Cache.ContainsKey($key)) {
                        $cachedProbe = $config.Cache[$key].VmafProbeCache.$probeKey
                        if ($cachedProbe -ne $null -and $cachedProbe.MaxAchievableVmaf -gt 0) {
                            $maxAchievableVmaf = $cachedProbe.MaxAchievableVmaf
                            $maxVmafCq = $cachedProbe.MaxVmafCq
                        }
                    }
                    
                    # Set up probe cache references inside cache for this file
                    $probeCache = $null
                    if ($config.CacheEnabled -and -not $isClipExtracted) {
                        if (-not $config.Cache.ContainsKey($key)) {
                            $config.Cache[$key] = @{
                                Path = $f.FullName
                                Signature = $sig
                                SettingsKey = $config.SettingsKey
                                VmafProbeCache = @{}
                            }
                        }
                        if (-not $config.Cache[$key].VmafProbeCache) {
                            $config.Cache[$key].VmafProbeCache = @{}
                        }
                        if (-not $config.Cache[$key].VmafProbeCache.ContainsKey($probeKey)) {
                            $config.Cache[$key].VmafProbeCache[$probeKey] = @{
                                Probes = @{}
                                MaxAchievableVmaf = 0.0
                                MaxVmafCq = 26
                            }
                        }
                        $probeCache = $config.Cache[$key].VmafProbeCache[$probeKey]
                    }

                    if ($maxAchievableVmaf -lt $minCeiling) {
                        Write-Output @{ Type="Log"; Msg="[WARN] Cached absolute Quality ceiling hit. Max achievable VMAF ($([math]::Round($maxAchievableVmaf,1))) is below minimum floor ($minCeiling). Skipping file entirely." }
                        $res.Msg = "Max VMAF < Min VMAF"
                        Write-Output @{ Index=$idx; Success=$false; Msg="Ceiling Skip"; Vmaf="---"; Total=$files.Count; File=$f.Name; Type="Result" }
                        continue
                    }
                    
                    # Pre-extract VMAF reference sample segments exactly once for this file
                    $refSamples = @()
                    if ($maxAchievableVmaf -ge $minCeiling) {
                        $samplePoints = if($config.VmafSamples -eq 1){ @($testDuration/2) } else { 1..$config.VmafSamples | ForEach-Object { ($testDuration/($config.VmafSamples+1))*$_ } }
                        Write-Output @{ Type="Log"; Msg="[PROBE] Pre-extracting $($samplePoints.Count) reference sample segments..." }
                        
                        $hwDecodeArgs = @()
                        if ($config.Encoder -match "nvenc") { $hwDecodeArgs = @("-hwaccel", "cuda") }
                        elseif ($config.Encoder -match "qsv") { $hwDecodeArgs = @("-hwaccel", "qsv") }
                        elseif ($config.Encoder -match "amf") { $hwDecodeArgs = @("-hwaccel", "d3d11va") }
                        
                        try {
                            for ($sIdx = 0; $sIdx -lt $samplePoints.Count; $sIdx++) {
                                if ($stopSignal[0]) { break }
                                $sp = $samplePoints[$sIdx]
                                $sampleSrc = Join-Path $config.TempDir "v_s_ref_${sIdx}_${uid}.mkv"
                                
                                $extractArgs = @("-y", "-loglevel", "error") + $hwDecodeArgs + @("-ss", "$sp", "-t", "$($config.VmafDur)", "-i", "$testPath", "-c:v", "copy", "-an", "$sampleSrc")
                                $p = Start-Process -FilePath "ffmpeg" -ArgumentList $extractArgs -NoNewWindow -Wait -PassThru
                                if ($p.ExitCode -eq 0 -and (Test-Path $sampleSrc)) {
                                    $refSamples += $sampleSrc
                                } else {
                                    Write-Output @{ Type="Log"; Msg="[WARN] Failed to extract sample segment at $sp" }
                                }
                            }
                        } catch {
                            Write-Output @{ Type="Log"; Msg="[WARN] Reference extraction failed: $_" }
                        }
                    }

                    $vmafLoopSuccess = $false
                    $attemptedCqs = @{}
                    $totalTargetsChecked = 0
                    $quickTestSkips = 0
                    foreach ($target in $vmafLadder) {
                        if ($stopSignal[0]) { break }
                        
                        $displayTarget = "$target"
                        if ($target -gt $maxAchievableVmaf + 0.5 -and -not $config.VmafFallbackEnabled) {
                            Write-Output @{ Type="Log"; Msg="[SKIP] Skipping VMAF Target $target (Ceiling is $([math]::Round($maxAchievableVmaf,1)))" }
                            continue
                        }
                        
                        if ($maxVmafCq -ne $null -and ($target -gt $maxAchievableVmaf + 0.5 -or [math]::Abs($target - $maxAchievableVmaf) -le 0.5)) {
                            if ($target -gt $maxAchievableVmaf + 0.5) {
                                Write-Output @{ Type="Log"; Msg="[PROBE] Target $target exceeds ceiling $([math]::Round($maxAchievableVmaf,1)). Fallback Enabled: using CQ $maxVmafCq." }
                                $displayTarget = "$([math]::Round($maxAchievableVmaf,1)) (Max VMAF)"
                            } else {
                                Write-Output @{ Type="Log"; Msg="[PROBE] Target $target is close to known ceiling $([math]::Round($maxAchievableVmaf,1)). Using CQ $maxVmafCq." }
                            }
                            $bestCQ = $maxVmafCq
                            $res.FinalVmaf = "$([math]::Round($maxAchievableVmaf,1))"
                        } else {
                            Write-Output @{ Type="Log"; Msg="[PROBE] Starting VMAF search (Target: $target) for: $($f.Name)" }
                            if ($refSamples.Count -eq 0) {
                                Write-Output @{ Type="Log"; Msg="[ERROR] Reference sample extraction failed." }
                                continue
                            }
                                
                                 $bestCQ = 26
                                 $bestScore = 0
                                 $maxScore = 0
                                 $maxScoreCq = 26
                                 $localProbes = @{}
                                 if ($probeCache -ne $null -and $probeCache.Probes -ne $null) {
                                     foreach ($key in $probeCache.Probes.Keys) {
                                         $localProbes[[int]$key] = $probeCache.Probes[$key]
                                     }
                                 }
                                 
                                  $cores = [System.Environment]::ProcessorCount
                                  $threads = [math]::max(1, $cores - 2)

                                 # --- Local helper: probe a single CQ value ---
                                 $probeSingleCq = {
                                     param([int]$cqVal, [string]$passLabel)
                                     if ($stopSignal[0]) { return $null }
                                     $strCq = [string]$cqVal
                                     
                                     # Check probe cache first
                                     if ($probeCache -ne $null -and $probeCache.Probes.ContainsKey($strCq)) {
                                         $cachedScore = $probeCache.Probes[$strCq]
                                         Write-Output @{ Type="Log"; Msg="[PROBE] ${passLabel}Cached CQ $cqVal -> VMAF: $([math]::Round($cachedScore,2))" }
                                         $localProbes[[int]$cqVal] = $cachedScore
                                         return $cachedScore
                                     }
                                     
                                     Write-Output @{ Type="Log"; Msg="[PROBE] ${passLabel}Probing Visual Fidelity at CQ $cqVal" }
                                     $scores = @()
                                     for ($sIdx = 0; $sIdx -lt $refSamples.Count; $sIdx++) {
                                         if ($stopSignal[0]) { break }
                                         $sampleSrc = $refSamples[$sIdx]
                                         $sampleEnc = Join-Path $config.TempDir "v_e_${sIdx}_${uid}.mkv"
                                         
                                         try {
                                             $encodeArgs = @("-y", "-loglevel", "error") + $hwDecodeArgs + @("-i", "$sampleSrc", "-c:v", "$($config.Encoder)", "-preset", "$($config.Preset)", "-$($config.Mode)", "$cqVal", "$sampleEnc")
                                             $p = Start-Process -FilePath "ffmpeg" -ArgumentList $encodeArgs -NoNewWindow -Wait -PassThru
                                             if ($p.ExitCode -eq 0 -and (Test-Path $sampleEnc)) {
                                                 $vmafArgs = @("-i", "$sampleEnc", "-i", "$sampleSrc", "-filter_complex", "libvmaf=n_threads=$threads", "-f", "null", "-")
                                                 $process = New-Object System.Diagnostics.Process
                                                 $process.StartInfo.FileName = "ffmpeg"
                                                 $process.StartInfo.Arguments = ($vmafArgs -join " ")
                                                 $process.StartInfo.UseShellExecute = $false
                                                 $process.StartInfo.CreateNoWindow = $true
                                                 $process.StartInfo.RedirectStandardError = $true
                                                 $process.StartInfo.RedirectStandardOutput = $true
                                                 $process.Start() | Out-Null
                                                 $vmafOut = $process.StandardError.ReadToEnd()
                                                 $process.WaitForExit()
                                                 
                                                 if ($vmafOut -match "VMAF score: (\d+\.\d+)") {
                                                     $scores += [double]$matches[1]
                                                 }
                                             }
                                         } finally {
                                             if (Test-Path $sampleEnc) { Remove-Item $sampleEnc -Force }
                                         }
                                     }
                                     
                                     if ($scores.Count -eq 0 -or $stopSignal[0]) { return $null }
                                     
                                     $avg = ($scores | Measure-Object -Average).Average
                                     Write-Output @{ Type="Log"; Msg="[PROBE] ${passLabel}CQ $cqVal -> VMAF: $([math]::Round($avg, 2))" }
                                     
                                     $localProbes[[int]$cqVal] = $avg
                                     # Update probe cache
                                     if ($probeCache -ne $null) {
                                         $probeCache.Probes[$strCq] = $avg
                                         if ($avg -gt $probeCache.MaxAchievableVmaf) {
                                             $probeCache.MaxAchievableVmaf = $avg
                                             $probeCache.MaxVmafCq = $cqVal
                                         }
                                         try {
                                             $config.Cache.Values | ConvertTo-Json -Depth 4 | Set-Content $config.CacheFile
                                         } catch {}
                                     }
                                     return $avg
                                 }

                                    # --- Boundary-Bounded Binary Search ---
                                    $cqMin = 1
                                    $cqMax = 51
                                    
                                    $bestCQ = $cqMin
                                    $bestScore = 0
                                    $maxScore = 0
                                    $maxScoreCq = $cqMin
                                    $skipSearch = $false
                                    
                                    $effectiveTarget = $target
                                    $targetUnreachable = $false

                                    # 1. Probe floor extreme (cqMax, lowest quality) first
                                    Write-Output @{ Type="Log"; Msg="[PROBE] Boundary: Testing VMAF floor at CQ $cqMax..." }
                                    $floorScore = & $probeSingleCq $cqMax "Boundary Floor: "
                                    if ($null -ne $floorScore -and $floorScore -gt 0) {
                                        if ($floorScore -gt $maxScore) { $maxScore = $floorScore; $maxScoreCq = $cqMax }
                                        $bestCQ = $cqMax
                                        $bestScore = $floorScore
                                        # If floor score meets or exceeds target, immediate exit with max compression
                                        if ($floorScore -ge $target) {
                                            Write-Output @{ Type="Log"; Msg="[PROBE] Floor CQ $cqMax already meets target ($([math]::Round($floorScore, 2)) >= $target). Max compression achieved." }
                                            $skipSearch = $true
                                        }
                                    }

                                    if ($stopSignal[0]) { $skipSearch = $true }

                                    # 2. Probe ceiling extreme (cqMin, highest quality) second
                                    if (-not $skipSearch) {
                                        Write-Output @{ Type="Log"; Msg="[PROBE] Boundary: Testing VMAF ceiling at CQ $cqMin..." }
                                        $ceilingScore = & $probeSingleCq $cqMin "Boundary Ceiling: "
                                        if ($null -ne $ceilingScore -and $ceilingScore -gt 0) {
                                            if ($ceilingScore -gt $maxScore) { $maxScore = $ceilingScore; $maxScoreCq = $cqMin }
                                            $bestCQ = $cqMin
                                            $bestScore = $ceilingScore
                                            # If ceiling score cannot reach target, adjust effective target
                                            if ($ceilingScore -lt $target) {
                                                $targetUnreachable = $true
                                                $effectiveTarget = $ceilingScore
                                                Write-Output @{ Type="Log"; Msg="[PROBE] Ceiling CQ $cqMin cannot reach target ($([math]::Round($ceilingScore, 2)) < $target). Adjusting effective VMAF target to known ceiling $([math]::Round($effectiveTarget, 2)) and continuing search." }
                                            }
                                        }
                                    }

                                    if ($stopSignal[0]) { $skipSearch = $true }

                                    # 3. Perform Stage 1 binary search targeting effective target
                                    if (-not $skipSearch) {
                                        $lowCq = $cqMin
                                        $highCq = $cqMax
                                        $finalMidCq = $cqMin
                                        $finalVmaf = if ($null -ne $ceilingScore) { $ceilingScore } else { 0.0 }
                                        $earlyPlateauBreak = $false
                                        
                                        for ($attempt = 1; $attempt -le 15; $attempt++) {
                                            if ($stopSignal[0]) { break }
                                            
                                            # Plateau Detection: check if we have 3 probed CQs with VMAF within 0.05 tolerance
                                            if ($localProbes.Count -ge 3) {
                                                $sortedKeys = $localProbes.Keys | Sort-Object { $localProbes[$_] } -Descending
                                                $plateauDetected = $false
                                                for ($i = 0; $i -lt ($sortedKeys.Count - 2); $i++) {
                                                    $k1 = $sortedKeys[$i]
                                                    $k2 = $sortedKeys[$i+1]
                                                    $k3 = $sortedKeys[$i+2]
                                                    if ([math]::Abs($localProbes[$k1] - $localProbes[$k3]) -le 0.05) {
                                                        $plateauCq = [math]::max($k1, [math]::max($k2, $k3))
                                                        Write-Output @{ Type="Log"; Msg="[PROBE] Plateau detected at CQ $k3, $k2, $k1 (Scores: $([math]::Round($localProbes[$k3], 2)), $([math]::Round($localProbes[$k2], 2)), $([math]::Round($localProbes[$k1], 2))). Stopping first search phase early." }
                                                        $finalMidCq = $plateauCq
                                                        $finalVmaf = $localProbes[$plateauCq]
                                                        $plateauDetected = $true
                                                        $earlyPlateauBreak = $true
                                                        break
                                                    }
                                                }
                                                if ($plateauDetected) { break }
                                            }
                                            
                                            if (($highCq - $lowCq) -le 1) { break }
                                            
                                            $midCq = [math]::Floor(($lowCq + $highCq) / 2)
                                            
                                            $score = & $probeSingleCq $midCq "Pass $attempt : "
                                            if ($score -eq $null) { break }
                                            
                                            if ($score -gt $maxScore) { $maxScore = $score; $maxScoreCq = $midCq }
                                            if ($bestScore -eq 0 -or [math]::Abs($score - $target) -lt [math]::Abs($bestScore - $target)) {
                                                $bestCQ = $midCq
                                                $bestScore = $score
                                            }
                                            $finalMidCq = $midCq
                                            $finalVmaf = $score
                                            Write-Output @{ Type="VmafUpdate"; Score=$score }
                                            
                                            if ($score -ge $effectiveTarget) {
                                                # Quality is enough/high, try to compress more (higher CQ value)
                                                $lowCq = $midCq
                                            } else {
                                                # Quality too low, move toward lower CQ (higher quality)
                                                $highCq = $midCq
                                            }
                                        }

                                        # 4. Stage 2 Refinement Binary Search (Directional Search)
                                        Write-Output @{ Type="Log"; Msg="[PROBE] Stage 1 finished. Final midpoint CQ $finalMidCq has VMAF $([math]::Round($finalVmaf, 2))." }
                                        
                                        $similarCq = $finalMidCq
                                        if ($finalVmaf -ge $effectiveTarget) {
                                            # Case A: Quality is sufficient. Search to the right (higher CQs / more compression)
                                            $candidates = @()
                                            foreach ($k in $localProbes.Keys) {
                                                if ($k -gt $finalMidCq) {
                                                    $candidates += $k
                                                }
                                            }
                                            if ($candidates.Count -gt 0) {
                                                $similarCq = $candidates | Sort-Object { [math]::Abs($localProbes[$_] - $effectiveTarget) } | Select-Object -First 1
                                            } else {
                                                $similarCq = $cqMax
                                            }
                                            Write-Output @{ Type="Log"; Msg="[PROBE] VMAF >= target. Refining search to the right (higher CQs) between $finalMidCq and $similarCq..." }
                                        } else {
                                            # Case B: Quality is too low. Search to the left (lower CQs / higher quality)
                                            $candidates = @()
                                            foreach ($k in $localProbes.Keys) {
                                                if ($k -lt $finalMidCq) {
                                                    $candidates += $k
                                                }
                                            }
                                            if ($candidates.Count -gt 0) {
                                                $similarCq = $candidates | Sort-Object { [math]::Abs($localProbes[$_] - $effectiveTarget) } | Select-Object -First 1
                                            } else {
                                                $similarCq = $cqMin
                                            }
                                            Write-Output @{ Type="Log"; Msg="[PROBE] VMAF < target. Refining search to the left (lower CQs) between $similarCq and $finalMidCq..." }
                                        }

                                        $refineLow = [math]::min($finalMidCq, $similarCq)
                                        $refineHigh = [math]::max($finalMidCq, $similarCq)

                                        # Run second binary search
                                        for ($attemptRef = 1; $attemptRef -le 9; $attemptRef++) {
                                            if ($stopSignal[0]) { break }
                                            if (($refineHigh - $refineLow) -le 1) { break }
                                            
                                            $midCq = [math]::Floor(($refineLow + $refineHigh) / 2)
                                            $score = & $probeSingleCq $midCq "Refinement Pass $attemptRef : "
                                            if ($score -eq $null) { break }
                                            
                                            if ($score -gt $maxScore) { $maxScore = $score; $maxScoreCq = $midCq }
                                            if ($bestScore -eq 0 -or [math]::Abs($score - $target) -lt [math]::Abs($bestScore - $target)) {
                                                $bestCQ = $midCq
                                                $bestScore = $score
                                            }
                                            Write-Output @{ Type="VmafUpdate"; Score=$score }
                                            
                                            if ($score -ge $effectiveTarget) {
                                                $refineLow = $midCq
                                            } else {
                                                $refineHigh = $midCq
                                            }
                                        }
                                    }

                                    # 5. Final selection: choose the best optimal CQ from all tested CQs
                                    if ($localProbes.Count -gt 0) {
                                        $validCqs = @()
                                        foreach ($c_cq in $localProbes.Keys) {
                                            $c_score = $localProbes[$c_cq]
                                            if ($c_score -ge ($effectiveTarget - 0.05)) {
                                                $validCqs += ,@($c_cq, $c_score)
                                            }
                                        }
                                        if ($validCqs.Count -gt 0) {
                                            # Choose the highest CQ (maximum compression)
                                            $bestPair = $validCqs | Sort-Object { $_[0] } -Descending | Select-Object -First 1
                                            $bestCQ = $bestPair[0]
                                            $bestScore = $bestPair[1]
                                            Write-Output @{ Type="Log"; Msg="[PROBE] Final evaluation: optimal CQ is $bestCQ with VMAF $([math]::Round($bestScore, 2))" }
                                        } else {
                                            # Fallback to closest overall in history
                                            $closestCq = $localProbes.Keys | Sort-Object { [math]::Abs($localProbes[$_] - $target) } | Select-Object -First 1
                                            $bestCQ = $closestCq
                                            $bestScore = $localProbes[$closestCq]
                                            Write-Output @{ Type="Log"; Msg="[PROBE] Final evaluation: fallback to closest CQ $bestCQ with VMAF $([math]::Round($bestScore, 2))" }
                                        }
                                        if ($probeCache -ne $null -and $targetUnreachable) {
                                            $probeCache.MaxVmafCq = $bestCQ
                                            $probeCache.MaxAchievableVmaf = $bestScore
                                            try {
                                                $config.Cache.Values | ConvertTo-Json -Depth 4 | Set-Content $config.CacheFile
                                            } catch {}
                                        }
                                    }
                            } finally {
                                foreach ($sampleSrc in $refSamples) {
                                    if (Test-Path $sampleSrc) { Remove-Item $sampleSrc -Force }
                                }
                            }
                            
                            $res.FinalVmaf = "$([math]::Round($bestScore, 1))"
                            
                            if ($maxScore -lt $minCeiling) {
                                Write-Output @{ Type="Log"; Msg="[WARN] Absolute Quality ceiling hit. Max achievable VMAF ($([math]::Round($maxScore,1))) is below minimum floor ($minCeiling). Skipping file entirely." }
                                $res.Msg = "Max VMAF < Min VMAF"
                                break
                            }
                            
                            if ($maxScore -lt $target - 0.5) {
                                $maxAchievableVmaf = $maxScore
                                $maxVmafCq = $bestCQ
                                if ($config.VmafFallbackEnabled) {
                                    Write-Output @{ Type="Log"; Msg="[WARN] Quality ceiling hit. Max achievable VMAF: $([math]::Round($maxScore,1)) (Target: $target). Fallback Enabled: using CQ $bestCQ." }
                                    $res.FinalVmaf = "$([math]::Round($maxScore,1))"
                                    $displayTarget = "$([math]::Round($maxScore,1)) (Max VMAF)"
                                } else {
                                    Write-Output @{ Type="Log"; Msg="[WARN] Quality ceiling hit. Max achievable VMAF: $([math]::Round($maxScore,1)) (Target: $target). Skipping target encode." }
                                    continue
                                }
                            }
                        }
                        
                        if ($attemptedCqs.ContainsKey($bestCQ)) {
                            Write-Output @{ Type="Log"; Msg="[SKIP] CQ $bestCQ has already been attempted for this file. Skipping." }
                            continue
                        }
                        $attemptedCqs[$bestCQ] = $true

                    if ($isClipExtracted) {
                        $trialOut = Join-Path $config.TempDir "clip_out_${uid}$ext"
                        Write-Output @{ Type="Log"; Msg="[QUICK TEST] Testing VMAF Target $displayTarget (CQ: $bestCQ) on clip for '$($f.Name)'..." }
                        $totalTargetsChecked++
                        $ffArgs = @("-y", "-loglevel", "info", "-stats", "-i", "$clipPath", "-c:v", "$($config.Encoder)", "-$($config.Mode)", "$bestCQ")
                        if ($config.Preset -and $config.Preset -ne "none") { $ffArgs += @("-preset", $config.Preset) }
                        $ffArgs += $target_audio_args
                        $ffArgs += $trialOut
                        
                        $success = Run-FFmpegWithProgress -ffArgs $ffArgs -fileIndex $idx -totalFiles $files.Count -fileDuration $quickTestDur
                        
                        if ($success -and (Test-Path $trialOut)) {
                            $clipEncodedSize = (Get-Item $trialOut).Length
                            if ($clipEncodedSize -lt $clipSize) {
                                $clipEncSizeDisp = if ($clipEncodedSize -gt 1MB) { "$((($clipEncodedSize)/1MB).ToString('F2')) MB" } else { "$((($clipEncodedSize)/1KB).ToString('F2')) KB" }
                                Write-Output @{ Type="Log"; Msg="[QUICK TEST] Clip target $displayTarget (CQ $bestCQ) succeeded for '$($f.Name)': $clipEncSizeDisp (Source clip: $clipSizeDisplay)." }
                                
                                # Now run final encode on FULL video!
                                Write-Output @{ Type="Log"; Msg="[ENCODE] Running final encode on full video (VMAF Target: $displayTarget, CQ: $bestCQ)..." }
                                $ffArgsFull = @("-y", "-loglevel", "info", "-stats", "-i", "$($f.FullName)", "-c:v", "$($config.Encoder)", "-$($config.Mode)", "$bestCQ")
                                if ($config.Preset -and $config.Preset -ne "none") { $ffArgsFull += @("-preset", $config.Preset) }
                                $ffArgsFull += $target_audio_args
                                $ffArgsFull += $tempOut
                                
                                $successFull = Run-FFmpegWithProgress -ffArgs $ffArgsFull -fileIndex $idx -totalFiles $files.Count -fileDuration $duration
                                
                                if ($successFull -and (Test-Path $tempOut)) {
                                    Write-Output @{ Type="Log"; Msg="[VALIDATE] Verifying output integrity..." }
                                    $newSize = (Get-Item $tempOut).Length
                                    if ($newSize -lt $f.OldSizeBytes) {
                                        $outDurIn = (& ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$tempOut" 2>$null | Out-String).Trim()
                                        if ($outDurIn -match "^\d+(\.\d+)?$") { $outDuration = [double]$outDurIn } else { $outDuration = 0 }
                                        if ($duration -gt 0 -and $outDuration -gt 0 -and [math]::Abs($duration - $outDuration) -le 2) {
                                            Move-Item $tempOut $finalOut -Force
                                            $res.Success = $true
                                            $res.NewSize = $newSize
                                            Write-Output @{ Type="Log"; Msg="[SUCCESS] Optimization complete. Saved $((($f.OldSizeBytes-$newSize)/1MB).ToString('F2')) MB" }
                                            $vmafLoopSuccess = $true
                                            if (Test-Path $trialOut) { Remove-Item $trialOut -Force }
                                            break
                                        } else { Write-Output @{ Type="Log"; Msg="[FAIL] Duration mismatch detected." } }
                                    } else { Write-Output @{ Type="Log"; Msg="[FAIL] Output larger than source." } }
                                    Remove-Item $tempOut -Force
                                } else {
                                    if (Test-Path $tempOut) { Remove-Item $tempOut -Force }
                                    Write-Output @{ Type="Log"; Msg="[FAIL] Full video encode failed for CQ $bestCQ." }
                                }
                            } else {
                                $clipEncSizeDisp = if ($clipEncodedSize -gt 1MB) { "$((($clipEncodedSize)/1MB).ToString('F2')) MB" } else { "$((($clipEncodedSize)/1KB).ToString('F2')) KB" }
                                Write-Output @{ Type="Log"; Msg="[QUICK TEST] Clip target $displayTarget (CQ $bestCQ) failed size check for '$($f.Name)': $clipEncSizeDisp (Source clip: $clipSizeDisplay). Skipping target." }
                                $quickTestSkips++
                            }
                            if (Test-Path $trialOut) { Remove-Item $trialOut -Force }
                        } else {
                            Write-Output @{ Type="Log"; Msg="[FAIL] Encoding failed for VMAF Target $target on clip for '$($f.Name)'." }
                        }
                    } else {
                        Write-Output @{ Type="Log"; Msg="[ENCODE] Running final encode (VMAF Target: $displayTarget, CQ: $bestCQ)..." }
                        $ffArgs = @("-y", "-loglevel", "info", "-stats", "-i", "$($f.FullName)", "-c:v", "$($config.Encoder)", "-$($config.Mode)", "$bestCQ")
                        if ($config.Preset -and $config.Preset -ne "none") { $ffArgs += @("-preset", $config.Preset) }
                        $ffArgs += $target_audio_args
                        $ffArgs += $tempOut
                        
                        $success = Run-FFmpegWithProgress -ffArgs $ffArgs -fileIndex $idx -totalFiles $files.Count -fileDuration $duration
                        
                        if ($success -and (Test-Path $tempOut)) {
                            if ($stopSignal[0]) { Remove-Item $tempOut -Force; break }
                            Write-Output @{ Type="Log"; Msg="[VALIDATE] Verifying output integrity..." }
                            $newSize = (Get-Item $tempOut).Length
                            if ($newSize -lt $f.OldSizeBytes) {
                                $outDurIn = (& ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$tempOut" 2>$null | Out-String).Trim()
                                if ($outDurIn -match "^\d+(\.\d+)?$") { $outDuration = [double]$outDurIn } else { $outDuration = 0 }
                                if ($duration -gt 0 -and $outDuration -gt 0 -and [math]::Abs($duration - $outDuration) -le 2) {
                                    Move-Item $tempOut $finalOut -Force
                                    $res.Success = $true
                                    $res.NewSize = $newSize
                                    Write-Output @{ Type="Log"; Msg="[SUCCESS] Optimization complete. Saved $((($f.OldSizeBytes-$newSize)/1MB).ToString('F2')) MB" }
                                    $vmafLoopSuccess = $true
                                    break
                                } else { Write-Output @{ Type="Log"; Msg="[FAIL] Duration mismatch detected." } }
                            } else { Write-Output @{ Type="Log"; Msg="[FAIL] Output larger than source." } }
                            Remove-Item $tempOut -Force
                        } else {
                            if (Test-Path $tempOut) { Remove-Item $tempOut -Force }
                            if (-not $stopSignal[0]) { Write-Output @{ Type="Log"; Msg="[FAIL] FFmpeg exited with error." } }
                        }
                    }
                    }
                    
                    if (-not $vmafLoopSuccess -and $res.Msg -ne "Max VMAF < Min VMAF" -and -not $stopSignal[0]) {
                        if ($quickTestSkips -gt 0 -and $quickTestSkips -eq $totalTargetsChecked) {
                            $res.Msg = "Skipped (Quick Test)"
                        } else {
                            $res.Msg = "Failed"
                        }
                    }
                } else {
                    $totalTargetsChecked = 0
                    $quickTestSkips = 0
                    foreach ($q in $config.QualityLadder) {
                        if ($stopSignal[0]) { break }
                        $qTrim = $q.Trim()
                        
                        if ($isClipExtracted) {
                            $trialOut = Join-Path $config.TempDir "clip_out_${uid}$ext"
                            Write-Output @{ Type="Log"; Msg="[QUICK TEST] Testing CQ $qTrim on clip for '$($f.Name)'..." }
                            $totalTargetsChecked++
                            $ffArgs = @("-y", "-loglevel", "info", "-stats", "-i", "$clipPath", "-c:v", "$($config.Encoder)", "-$($config.Mode)", "$qTrim")
                            if ($config.Preset -and $config.Preset -ne "none") { $ffArgs += @("-preset", $config.Preset) }
                            $ffArgs += $target_audio_args
                            $ffArgs += $trialOut
                            
                            $success = Run-FFmpegWithProgress -ffArgs $ffArgs -fileIndex $idx -totalFiles $files.Count -fileDuration $quickTestDur
                            
                            if ($success -and (Test-Path $trialOut)) {
                                $clipEncodedSize = (Get-Item $trialOut).Length
                                if ($clipEncodedSize -lt $clipSize) {
                                    $clipEncSizeDisp = if ($clipEncodedSize -gt 1MB) { "$((($clipEncodedSize)/1MB).ToString('F2')) MB" } else { "$((($clipEncodedSize)/1KB).ToString('F2')) KB" }
                                    Write-Output @{ Type="Log"; Msg="[QUICK TEST] Clip CQ $qTrim succeeded for '$($f.Name)': $clipEncSizeDisp (Source clip: $clipSizeDisplay)." }
                                    Write-Output @{ Type="Log"; Msg="[ENCODE] Running final encode on full video (CQ: $qTrim)..." }
                                    $ffArgsFull = @("-y", "-loglevel", "info", "-stats", "-i", "$($f.FullName)", "-c:v", "$($config.Encoder)", "-$($config.Mode)", "$qTrim")
                                    if ($config.Preset -and $config.Preset -ne "none") { $ffArgsFull += @("-preset", $config.Preset) }
                                    $ffArgsFull += $target_audio_args
                                    $ffArgsFull += $tempOut
                                    
                                    $successFull = Run-FFmpegWithProgress -ffArgs $ffArgsFull -fileIndex $idx -totalFiles $files.Count -fileDuration $duration
                                    if ($successFull -and (Test-Path $tempOut)) {
                                        Write-Output @{ Type="Log"; Msg="[VALIDATE] Verifying output integrity..." }
                                        $newSize = (Get-Item $tempOut).Length
                                        if ($newSize -lt $f.OldSizeBytes) {
                                            $outDurIn = (& ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$tempOut" 2>$null | Out-String).Trim()
                                            if ($outDurIn -match "^\d+(\.\d+)?$") { $outDuration = [double]$outDurIn } else { $outDuration = 0 }
                                            if ($duration -gt 0 -and $outDuration -gt 0 -and [math]::Abs($duration - $outDuration) -le 2) {
                                                Move-Item $tempOut $finalOut -Force
                                                $res.Success = $true
                                                $res.NewSize = $newSize
                                                Write-Output @{ Type="Log"; Msg="[SUCCESS] Optimization complete. Saved $((($f.OldSizeBytes-$newSize)/1MB).ToString('F2')) MB" }
                                                if (Test-Path $trialOut) { Remove-Item $trialOut -Force }
                                                break
                                            } else { Write-Output @{ Type="Log"; Msg="[FAIL] Duration mismatch detected." } }
                                        } else { Write-Output @{ Type="Log"; Msg="[FAIL] Output larger than source." } }
                                        Remove-Item $tempOut -Force
                                    } else {
                                        if (Test-Path $tempOut) { Remove-Item $tempOut -Force }
                                    }
                                } else {
                                    $clipEncSizeDisp = if ($clipEncodedSize -gt 1MB) { "$((($clipEncodedSize)/1MB).ToString('F2')) MB" } else { "$((($clipEncodedSize)/1KB).ToString('F2')) KB" }
                                    Write-Output @{ Type="Log"; Msg="[QUICK TEST] Clip CQ $qTrim failed size check for '$($f.Name)': $clipEncSizeDisp (Source clip: $clipSizeDisplay). Skipping." }
                                    $quickTestSkips++
                                }
                                if (Test-Path $trialOut) { Remove-Item $trialOut -Force }
                            } else {
                                if (Test-Path $trialOut) { Remove-Item $trialOut -Force }
                            }
                        } else {
                            Write-Output @{ Type="Log"; Msg="[ENCODE] Running final encode (CQ: $qTrim)..." }
                            $ffArgs = @("-y", "-loglevel", "info", "-stats", "-i", "$($f.FullName)", "-c:v", "$($config.Encoder)", "-$($config.Mode)", "$qTrim")
                            if ($config.Preset -and $config.Preset -ne "none") { $ffArgs += @("-preset", $config.Preset) }
                            $ffArgs += $target_audio_args
                            $ffArgs += $tempOut
                            
                            $success = Run-FFmpegWithProgress -ffArgs $ffArgs -fileIndex $idx -totalFiles $files.Count -fileDuration $duration
                            
                            if ($success -and (Test-Path $tempOut)) {
                                if ($stopSignal[0]) { Remove-Item $tempOut -Force; break }
                                Write-Output @{ Type="Log"; Msg="[VALIDATE] Verifying output integrity..." }
                                $newSize = (Get-Item $tempOut).Length
                                if ($newSize -lt $f.OldSizeBytes) {
                                    $outDurIn = (& ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$tempOut" 2>$null | Out-String).Trim()
                                    if ($outDurIn -match "^\d+(\.\d+)?$") { $outDuration = [double]$outDurIn } else { $outDuration = 0 }
                                    if ($duration -gt 0 -and $outDuration -gt 0 -and [math]::Abs($duration - $outDuration) -le 2) {
                                        Move-Item $tempOut $finalOut -Force
                                        $res.Success = $true
                                        $res.NewSize = $newSize
                                        Write-Output @{ Type="Log"; Msg="[SUCCESS] Optimization complete. Saved $((($f.OldSizeBytes-$newSize)/1MB).ToString('F2')) MB" }
                                        break
                                    } else { Write-Output @{ Type="Log"; Msg="[FAIL] Duration mismatch detected." } }
                                } else { Write-Output @{ Type="Log"; Msg="[FAIL] Output larger than source." } }
                                Remove-Item $tempOut -Force
                            } else {
                                if (Test-Path $tempOut) { Remove-Item $tempOut -Force }
                                if (-not $stopSignal[0]) { Write-Output @{ Type="Log"; Msg="[FAIL] FFmpeg exited with error." } }
                            }
                        }
                    }
                }
            } else { $res.Msg = "Path Error" }

            if (-not $stopSignal[0] -and -not $res.Success) {
                if ($quickTestSkips -gt 0 -and $quickTestSkips -eq $totalTargetsChecked) {
                    $res.Msg = "Skipped (Quick Test)"
                } else {
                    if ($res.Msg -ne "Max VMAF < Min VMAF") { $res.Msg = "Failed" }
                }
                try {
                    if ($config.OnFail -eq "Move" -and $res.Msg -ne "Max VMAF < Min VMAF" -and $res.Msg -ne "Skipped (Quick Test)") {
                        $unoptDir = Join-Path $dir "Unoptimizable"
                        if (-not (Test-Path $unoptDir)) { New-Item -ItemType Directory -Path $unoptDir | Out-Null }
                        $dest = Join-Path $unoptDir $f.Name
                        if (Test-Path $f.FullName) { Move-Item $f.FullName $dest -Force }
                        Write-Output @{ Type="Log"; Msg="[WARN] Moved failed file to 'Unoptimizable'." }
                    } elseif ($config.OnFail -eq "Delete" -and $res.Msg -ne "Max VMAF < Min VMAF" -and $res.Msg -ne "Skipped (Quick Test)") {
                        if (Test-Path $f.FullName) { Remove-Item $f.FullName -Force }
                        Write-Output @{ Type="Log"; Msg="[WARN] Deleted failed file." }
                    }
                } catch { Write-Output @{ Type="Log"; Msg="[FAIL] Failed to execute OnFail action: $_" } }
            }

            if ($config.CacheEnabled -and -not $stopSignal[0]) { 
                if (-not $res.Success -and $config.OnFail -eq "Ignore") { 
                    $config.Cache[$key]=@{Path=$f.FullName; Signature=$sig; SettingsKey=$config.SettingsKey; Reason=$res.Msg; LastTried=(Get-Date).ToString("o") } 
                } elseif ($res.Success) { 
                    $config.Cache[$key]=@{Path=$f.FullName; Signature=$sig; SettingsKey=$config.SettingsKey; Status="Optimized" } 
                }
                $config.Cache.Values | ConvertTo-Json -Depth 4 | Set-Content $config.CacheFile 
            }            
            if ($clipPath -and (Test-Path $clipPath)) {
                try { Remove-Item $clipPath -Force } catch {}
            }
            if ($null -ne $refSamples) {
                foreach ($s in $refSamples) {
                    if (Test-Path $s) { try { Remove-Item $s -Force } catch {} }
                }
            }
            if ($stopSignal[0]) { 
                Write-Output @{ Index=$idx; Success=$false; Msg="Stopped"; Vmaf="---"; Total=$files.Count; File=$f.Name; Type="Result" }
                break 
            }
            Write-Output @{ Index=$idx; Success=$res.Success; NewSize=$res.NewSize; Msg=$res.Msg; Vmaf=$res.FinalVmaf; Total=$files.Count; File=$f.Name; Type="Result" }
        }
        Write-Output @{ Type="Log"; Msg=">>> BACKEND PROCESS COMPLETED IN $($sw.Elapsed.ToString('hh\:mm\:ss'))" }
        } catch {
            Write-Output @{ Type="Log"; Msg="[CRITICAL ERROR] Job crashed: $_" }
            Write-Output @{ Type="Log"; Msg="StackTrace: $($_.ScriptStackTrace)" }
        }
    }
    
    $powershell=[PowerShell]::Create().AddScript($job).AddArgument($global:videoFiles).AddArgument($config).AddArgument($global:StopSignal); $asyncResult=$powershell.BeginInvoke()
    $timer=New-Object System.Windows.Threading.DispatcherTimer; $timer.Interval=[TimeSpan]::FromMilliseconds(200)
    $timer.Add_Tick({
        $global:StopSignal[0] = $global:stopRequested
        if ($null -ne $powershell) {
            if ($null -ne $powershell.Streams.Output) {
                $outputs = $powershell.Streams.Output.ReadAll()
                foreach ($out in $outputs) {
                    if ($out.Type -eq "VmafUpdate") { $statVmaf.Text=[math]::Round($out.Score,1); continue }
                    if ($out.Type -eq "Log") { Add-Log $out.Msg; continue }
                    if ($out.Type -eq "Progress") { 
                        $lblStatus.Text = $out.Msg
                        $progressMain.Value = $out.Pct
                        continue 
                    }
                    if ($out.Type -eq "Update") { $global:videoFiles[$out.Index].Status = $out.Status; continue }
                    if ($out.Type -eq "Result") {
                        $item=$global:videoFiles[$out.Index]
                        if ($out.Success) { 
                            $item.Status="Done"
                            $item.NewSize=Format-Bytes $out.NewSize
                            $saving=$item.OldSizeBytes-$out.NewSize
                            $item.Saving="$([Math]::Round(($saving/$item.OldSizeBytes)*100,1))%"
                            $global:totalSavedBytes+=$saving
                            $global:totalOriginalBytes+=$item.OldSizeBytes
                            Add-Log "Success: $($out.File) [VMAF: $($out.Vmaf)]" 
                        } else { 
                            $item.Status=$out.Msg
                            $item.Saving="0%" 
                        }
                        $global:processedCount++
                        $statSaved.Text=Format-Bytes $global:totalSavedBytes
                        if($global:totalOriginalBytes -gt 0){$statEff.Text="$([Math]::Round(($global:totalSavedBytes/$global:totalOriginalBytes)*100,1))%"}
                        $pct=[Math]::Round(($global:processedCount/$out.Total)*100)
                        $progressMain.Value=$pct
                    }
                }
            }
            
            if ($null -ne $powershell.Streams.Error) {
                $errors = $powershell.Streams.Error.ReadAll()
                foreach ($err in $errors) {
                    Add-Log "[JOB ERROR] $err"
                }
            }
            
            $dgFiles.Items.Refresh()
            if ($asyncResult.IsCompleted) { 
                $timer.Stop()
                $outputs = $powershell.Streams.Output.ReadAll()
                foreach ($out in $outputs) { if ($out.Type -eq "Log") { Add-Log $out.Msg } }
                $errors = $powershell.Streams.Error.ReadAll()
                foreach ($err in $errors) { Add-Log "[JOB ERROR] $err" }
                
                $btnStart.IsEnabled=$true; $btnBrowse.IsEnabled=$true; $btnStop.Visibility="Collapsed"; $lblStatus.Text=if($global:stopRequested){"Stopped"}else{"Finished"};  $powershell.Dispose()
                return 
            }
        }
    })
    $timer.Start()
})
$window.ShowDialog() | Out-Null
