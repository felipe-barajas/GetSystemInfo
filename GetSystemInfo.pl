#!/usr/bin/perl

use strict;
use warnings;
use Term::Cap;
use Term::ANSIColor;
use List::Util qw[min max];

#Array containing all the dmidecode keys to get cpu information
my @cpu_keywords=["Socket Designation:",
                  "Family:",
                  "Manufacturer:",
                  "Version:",
                  "Max Speed:",
                  "Current Speed:",
                  "Core Count:",
                  "Thread Count:"];

#Array containing all the dmidecode keys to get system information
my @system_keywords=["Product Name:",
                  "Manufacturer:",
                  "Version:"];

#Array containing all the dmidecode keys to get bios information
my @bios_keywords=["Vendor:",
                  "Release Date:",
                  "Version:"];

#Array containing all the dmidecode keys to get mainboard information
my @motherboard_keywords=["Manufacturer:",
                  "Product Name:",
                  "Version:",
                  "Serial Number:"];

#Array containing all the dmidecode keys to get memory information
my @memory_keywords=["Size:",
                  "Type:",
                  "Speed:",
                  "Manufacturer:",
                  "Part Number:",
                  "Clock Speed:"];

#Array containing all the dmidecode keys to get disk information
my @disk_keywords=["Model Number:",
                  "Model Family:",
                  "Device Model:",
                  "Serial Number:",
                  "User Capacity:",
                  "Total NVM Capacity:",
                  "Namespace 1 Size/Capacity:",
                  "Firmware Version:",
                  "Form Factor:",
                  "SATA Version is:"];

#function will parse many instances of the same resource.
#this is used for example for CPU info where there could be many CPUs.
#each resource has a key and a value.  The keys are to be used from global variables
#the values are the parsed result of looking for the keys.
#the output will be returned in the form of an array of hashes.
sub parse_info {
  my $input_to_parse; #the input given containing all information to parse
  my $header;  #string be used to identify the beginning of new resource instance
  my $keywords_ref;  #keywords to search for. Given as an array reference

  ($header, $keywords_ref, $input_to_parse) = @_;
  my @keywords = @{$keywords_ref};

  my @instances_output; #output to return. Contains all parsed info in array of hashes

  my $index=-1; #an array index. start at -1 to indicate no header has been found yet

  #parse output line by line
  foreach my $line (split(/\n/, $input_to_parse)) {
    #look for the header to indicate a new instance (beginnng) of the information
    if ($line =~ /$header/) {
      $index=$index+1; #increment index to mark a new instance
      my %key_values;  #createy new hash
      $instances_output[$index]=\%key_values; #store hash reference in this index
    }

    foreach my $key (@keywords) {
      #see if line matches a key. index must be >=0 to indicate header found
      if ($line =~ /^[\s]?$key(.*)/ && $index >= 0) {
        my $value=$1;
        $value =~ s/ +/ /;
        if (exists($instances_output[$index]->{$key})){
          printf("WARNING. Value for $key is being overwritten!!\n");
        }
        $instances_output[$index]->{$key} = $value; #store the value in hash
      }
    }
  }

  return \@instances_output; #return a reference to this array of hashes
}

sub parse_nvme_info {
  my @array_input;
  my $index=0;
  my $linenum=0;
  my @headers;
  my @header_lengths;

  my $test=`which nvme 2>/dev/null`;
  if ( length($test) < 1){
    $array_input[$index]->{"WARNING:"} = "Please install the nvme utility (nvme-cli) to list NVMe devices";
    return \@array_input;
  }

  foreach my $line (split(/\n/, `nvme list`)){
    if ($linenum == 0){
      foreach my $header (split(/\s+/, $line)){
        unless ($header =~ /Rev/){
          push(@headers, $header . ":");
        }
      }
    }
    elsif ($linenum == 1){
      foreach my $header (split(/\s+/, $line)){
        my $count=length($header);
        push(@header_lengths, $count);
      }
    }
    elsif ( scalar(@headers)>0 && scalar(@headers)==scalar(@header_lengths) ) {
        my $last_len=0;
        my $i=0;
        foreach my $header_len (@header_lengths){
          my $value = substr($line, $last_len, $header_len);
          $value =~ s/^\s+|\s+$//g ; #remove white space from both ends
          my $header=$headers[$i];
          if ($header =~ /Model/i && $line =~ /dev\/(\w+)/){
            my $device =$1;
            my $market_name=`nvme intel market-name /dev/$device | tail -n 1`;
            chomp($market_name);
            $array_input[$index]->{"Marketing Name:"} = $market_name;
          }
          $array_input[$index]->{$header} = $value;
          $last_len += $header_len+1;
          $i++;
        }
        $index++;
    }
    $linenum++
  }

  return \@array_input;
}

#function will print the information already gathered in given array reference
sub print_info {
  my $array_ref; #contains a reference to an array of hashes
  my $title; #title of resource info
  my $subtitle; #subtitle of resource info
  my $additional_ref; #contains additional info in a hash (optional)

  ($array_ref, $title, $subtitle, $additional_ref) = @_;

  my @array_input = @{$array_ref}; #dereference array of hashes
  my $max_length = 0;
  my $num_instances=scalar(@array_input);

  #counters
  my $i=0;
  my $display_num=$i+1;

  print colored(['bright_white on_blue'], "\n$title");
  print color('reset');
  print "\n";

  #if additional hash info was given then print it
  #this is meant to be used as a way to print global or generic info which
  #may not be part of a specific resource (or instance)
  if (defined $additional_ref){
    my %extra_info = %{$additional_ref};
    my @keys = keys(%extra_info); #get the keys from the hash
    #print the key - value pairs in hash
    foreach my $key (@keys) {
         my $value = $extra_info{$key};
         print "\n";
         print colored(['bright_white'], " $key $value");
         print color('reset');
         print "\n";
    }
    print "\n";
  }

  while ($i < $num_instances ) {
    if ($num_instances > 1){
      #print subtitle only if we have many instances to display
      print colored(['bright_white'], " $subtitle $display_num");
      print color('reset');
      print "\n";
    }

    my $hash_ref = $array_input[$i]; #get the hash at this array index
    my %hash=%{$hash_ref}; #dereference hash
    my @keys = keys(%hash); #get the keys from the hash

    foreach my $key (@keys) {
      #store the max length of keys for later display
      $max_length = max($max_length, length($key)+2); #+2 for padding
    }

    #print the key - value pairs in hash
     foreach my $key (@keys) {
         my $value = $hash{$key};
         printf("%${max_length}s %-s\n", $key, $value);
     }
     print "\n";
     $i=$i+1;
     $display_num=$i+1;
  }
}

#function will sum numeric information based on a keyword to find
sub sum_info {
  my $array_ref; #contains a reference to an array of hashes
  my $keyword; #keyword to find for the sum
  my $stored_keyword; #the keyword to store the sum under

  ($array_ref, $keyword, $stored_keyword) = @_;

  my @array_input = @{$array_ref}; #dereference array of hashes
  my $max_length = 0;
  my $num_instances=scalar(@array_input);

  #counters
  my $i=0;
  my $sum=0;
  my $unit='';

  while ($i < $num_instances ) {
    my $hash_ref = $array_input[$i]; #get the hash at this array index
    my %hash=%{$hash_ref}; #dereference hash
    my @keys = keys(%hash); #get the keys from the hash
    #go through keys and if key matches keyword and value is numeric sum it
     foreach my $key (@keys) {
       if ($key =~ /$keyword/) {
         my $value = $hash{$key};
         if ( $value =~ /\s+(\d+)\s+(\w+)/){ #get numeric part
           my $numeric_value=$1;
           my $value_unit=$2;
           #make sure the unit matches
           if( $unit eq '') {
             $unit=$value_unit;
           }
           unless ($unit eq $value_unit){
             printf("WARNING. Value of unit changed from $unit to $value_unit !!\n");
           }
           $sum=$sum+$numeric_value;
         }
       }
     }
    $i=$i+1;
  }

  my %output;
  $output{$stored_keyword}="$sum $unit";

  return \%output; #return reference to output hash
}

#function will return a copy of input without instances of matched value/keyword
sub remove_info {
  my $array_ref; #contains a reference to an input of array of hashes
  my $remove_keyword; #keyword to find in the array
  my $remove_value; #value for keyword to parse in the array and remove

  ($array_ref, $remove_keyword, $remove_value) = @_;

  my @array_input = @{$array_ref}; #dereference array of hashes
  my $max_length = 0;
  my $num_instances=scalar(@array_input);

  my @updated_array; #copy of array_input minus data removed

  #counters
  my $i=0;
  my $sum=0;
  my $unit='';

  while ($i < $num_instances ) {
    my $hash_ref = $array_input[$i]; #get the hash at this array index
    my %hash=%{$hash_ref}; #dereference hash
    my @keys = keys(%hash); #get the keys from the hash
    my $found_keyword = 0;
    #go through keys and if key matches keyword and value is numeric sum it
     foreach my $key (@keys) {
       my $value = $hash{$key};
       if ($key eq $remove_keyword) {
         if ( $value =~ /$remove_value/){  #found the value to remove in the key
           $found_keyword = 1 ;
          }
       }
     }
     if ($found_keyword == 0){  #only copy if value for key was NOT found
        push(@updated_array, \%hash);
     }
    $i=$i+1;
  }

  return \@updated_array; #return reference to output hash
}

#functions below get specific pieces of information
sub get_cpu_info() {
  my $cpu_header="Processor Information";
  my $input = `dmidecode -t processor`;
  my $array_ref = parse_info($cpu_header, @cpu_keywords, $input);
  print_info($array_ref, "CPU INFORMATION", "CPU #");
}

sub get_system_info() {
  my $system_header="System Information";
  my $input=`dmidecode -t system`;
  my $array_ref = parse_info($system_header, @system_keywords, $input);
  print_info($array_ref, "SYSTEM INFORMATION", "System");
}

sub get_bios_info() {
  my $bios_header="BIOS Information";
  my $input=`dmidecode -t bios`;
  my $array_ref = parse_info($bios_header, @bios_keywords, $input);
  print_info($array_ref, "BIOS INFORMATION", "BIOS");
}

sub get_memory_info() {
  my $memory_header="Memory Device";
  my $input=`dmidecode -t memory`;
  my $array_ref = parse_info($memory_header, @memory_keywords, $input);
  # sum the size in keyword 'Size:' and report it as 'Total Memory Size:'
  my $sum_info_ref = sum_info($array_ref, "Size:", "Total Memory Size:");
  # remove any instance of "NO DIMM" in the keyword "Part Number" so as to not report empty slot info
  my $updated_array_ref = remove_info($array_ref, "Part Number:", "NO DIMM");
  print_info($updated_array_ref, "MEMORY INFORMATION", "Memory Module #", $sum_info_ref);
}

sub get_motherboard_info() {
  my $motherboard_header="Base Board Information";
  my $input=`dmidecode -t baseboard`;
  my $array_ref = parse_info($motherboard_header, @motherboard_keywords, $input);
  print_info($array_ref, "MOTHERBOARD INFORMATION", "Motherboard");
}

sub get_disk_info() {
  #Get NVMe drives first
  my $nvme_array_ref = parse_nvme_info();
  my @nvme_array_info = @{$nvme_array_ref};
  my $disk_header="START OF INFORMATION SECTION";
  my $input=" ";
  my $devs=`lsblk | grep disk | awk '{ print \$1 }'`;
  my $smartctl_is_avail=1;
  my $array_ref='';

  my $test=`which smartctl 2>/dev/null`;
  if ( length($test) < 1){
    $smartctl_is_avail=0;
  }

  foreach my $dev (split(/\n/, $devs )) {
    # avoid printing information on NVMe devices already found
    my $already_found = 0;
    foreach my $nvme_ref (@nvme_array_info) {
      my $hash_ref = $nvme_ref; #get the hash at this array index
      my %hash=%{$hash_ref}; #dereference hash
      if ( $hash{"Node:"} =~ /$dev/ ) {
        $already_found = 1;
      }
    }
    if ( $smartctl_is_avail==1 && $already_found == 0){
      my $dev_input = `smartctl -a /dev/$dev`;
      chomp $dev_input;
      $input=$input . "\n" . $dev_input
    }
  }

 if ( $smartctl_is_avail==1){
    $array_ref = parse_info($disk_header, @disk_keywords, $input);
  }
  else {
    my @tmp_array;
    $tmp_array[0]->{"WARNING:"} = "Please install the smartctl tool (smartmontools) to list disk devices";
    $array_ref=\@tmp_array;

  }
  print_info($array_ref, "DISK INFORMATION", "Disk #");
  print_info($nvme_array_ref, "NVME DISK INFORMATION", "Disk #");
}

sub get_pci_info() {
  my @array_info;
  # look for network, NVMe and VGA pci devices
  my $devs=`lspci | grep -iE 'network|ethernet|vga|nvme|ssd'`;
  foreach my $dev (split(/\n/, $devs )) {
    #match something like '18:00.0 Ethernet controller: Intel X710/X557-AT'
    if ($dev =~ /(\w+:\w+.\w+)\s+([\w\s-]+):\s+(.*)/){
      my %pci_info; #prepare new hash
      $pci_info{"PCI Address:"} = $1;
      $pci_info{"Type:"} = $2;
      $pci_info{"Device Name:"} = $3;
      push(@array_info, \%pci_info);
    }
  }
  print_info(\@array_info, "PCI INFORMATION", "PCI Device #");
}

sub get_cas_info() {
  my $cas_path="`which casadm 2>/dev/null`";
  if (length($cas_path)>0){
    print colored(['bright_white on_blue'], "\nCAS INFORMATION");
    print color('reset');
    print "\n";
    my $cas_info=`casadm -V  | grep -E 'CAS' |  sed "s/[│║]/ /g" 2>/dev/null`;
    print $cas_info;
  }
  else {
    print colored(['bright_white on_blue'], "\nCAS IS NOT INSTALLED");
    print color('reset');
    print "\n";
  }
}

sub get_os_info() {
  my %os_info;
  my @array_info;
  #get kernel info without extra line chars
  my $redhat_version_file="/etc/redhat-release";
  my $linux_version_file="/etc/system-release";
  if (-e $redhat_version_file) {
    $os_info{"Redhat Version:"} = `cat $redhat_version_file | tr '\n' ' '`;
  }
  elsif (-e $linux_version_file) {
    $os_info{"Linux Version:"} = `cat $linux_version_file | tr '\n' ' '`;
  }
  $os_info{"Operating System:"} = `uname -o | tr '\n' ' '`;
  $os_info{"System Processor:"} =  `uname -p| tr '\n' ' '`;
  $os_info{"Kernel Name:"} =  `uname -s| tr '\n' ' '`;
  $os_info{"Kernel Version:"} = `uname -v| tr '\n' ' '`;
  $os_info{"Kernel Release:"} = `uname -r| tr '\n' ' '`;
  $os_info{"Kernel Modules:"} = `lsmod | grep -v Module | awk '{ print \$1 }' | tr '\n' ','`;

  $array_info[0] = \%os_info;
  print_info(\@array_info, "OS INFORMATION", "OS");
}

# MAIN_STARTS_HERE

get_os_info();
get_system_info();
get_motherboard_info();
get_pci_info();
get_bios_info();
get_cpu_info();
get_memory_info();
get_disk_info();
get_cas_info();
