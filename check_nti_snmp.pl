#!/usr/bin/perl -w
# nagios: -epn

#
# ============================== SUMMARY =====================================http://www.networktechinc.com/download/check_nti_snmp.pl
#
# Program : check_nti_snmp.pl
# Version : 1.2
# Date    : 11/05/2012
# Maintained by : Suvidh Kankariya <suvidh/kankariya@ntigo.com>
# Credit  : Bob Foerster 
# Summary : Nagios plugin to aid in monitoring Network Technologies Inc products.
# Licence : GPL - summary below, full text at http://www.fsf.org/licenses/gpl.txt
#
# =========================== PROGRAM LICENSE =================================
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
# ===================== INFORMATION ABOUT THIS PLUGIN =========================
#
# This plugin checks the status of Network Technologies Inc products via SNMP.
# Devices can be monitored either as a single service or as a service for each
# individual sensor being monitored.  
#
# The script can also assist in generating the proper Nagios configuration for
# use with the script.
#
# This program is written and maintained by:
#   Bob Foerster <robert.foerster@ntigo.com>
#
# Some small pieces based on check_dell_openmanage.pl plugin by:
#   Jason Ellison - infotek@gmail.com
#
# ============================= SETUP NOTES ====================================
#
# Copy this file to your Nagios installation folder in "libexec/". Rename
# to "check_nti_snmp.pl".  Make sure that this script has the proper permissions.
#
# Make sure that the product you wish to monitor has SNMP enabled.
# The perl module "Net::SNMP" must be installed on on the machine on which
# Nagios is running.
#
# perl -MCPAN -e shell
# cpan> install Net::SNMP
#
#
# ========================= SETUP EXAMPLES ==================================
#
# You'll need to add a command to Nagios for this plugin similar to the following:
# define command{
#       command_name    check_nti_snmp
#       command_line    $USER1$/check_nti_snmp.pl -H $HOSTADDRESS$ $ARG1$
#       }
#
# Then, you'll need to define services for each item you wish to monitor.  You can
# generate the necessary services using the "-m generate" option to the script.
#
#
# =============================== CHANGES =================================
# 
# 1.0  - 10/12/2009 - Initial revision
# 
# 1.1  - 11/02/2009 - Add support for digital inputs on SEMS-16
#                         and dry contacts/water sensor on MINI
# 1.2  - 05/11/2012 - Add support for MINI-LXO and SEMS-2D
# 1.3  - 07/25/2013 - Add support for ENVIROMUX-16D, ENVIROMUX-5D
#

use strict;
use Getopt::Long;
use File::Basename;


# Supported product definitions
#
# For sake of familiarity, the key of each system  should match the specifier in 
# the MIB of each product.  Also, sensor classes should match the tables in the MIBs.
my %systems = (
    enviromuxSems16 => { 
        product_name => "ENVIROMUX-SEMS-16",
        sensors => {
            intSensors => {
                num_sensors => 3,
                handler => \&interpret_sensor_response,
                check_oids => {
                    type => ".1.3.6.1.4.1.3699.1.1.2.1.4.1.1.2",
                    description => ".1.3.6.1.4.1.3699.1.1.2.1.4.1.1.3",
                    value => ".1.3.6.1.4.1.3699.1.1.2.1.4.1.1.6",
                    units => ".1.3.6.1.4.1.3699.1.1.2.1.4.1.1.8",
                    status => ".1.3.6.1.4.1.3699.1.1.2.1.4.1.1.9"
                }
            },
            extSensors => {
                num_sensors => 32,
                handler => \&interpret_sensor_response,
                check_oids => {
                    type => ".1.3.6.1.4.1.3699.1.1.2.1.5.1.1.2",
                    description => ".1.3.6.1.4.1.3699.1.1.2.1.5.1.1.3",
                    value => ".1.3.6.1.4.1.3699.1.1.2.1.5.1.1.7",
                    units => ".1.3.6.1.4.1.3699.1.1.2.1.5.1.1.9",
                    status => ".1.3.6.1.4.1.3699.1.1.2.1.5.1.1.10"
                }
            }, 
            digInputs => {
                num_sensors => 8,
                handler => \&interpret_sensor_response,
                type => 18, # hardcode a digital input sensor type
                check_oids => {
                    description => ".1.3.6.1.4.1.3699.1.1.2.1.6.1.1.2",
                    value => ".1.3.6.1.4.1.3699.1.1.2.1.6.1.1.5",
                    status => ".1.3.6.1.4.1.3699.1.1.2.1.6.1.1.7"
                }
            },        
       }
    },
    envMiniLxo => { 
        product_name => "ENVIROMUX-MINI-LXO",
        sensors => {
            extSensors => {
                num_sensors => 4,
                handler => \&interpret_sensor_response,
                check_oids => {
                    type => ".1.3.6.1.4.1.3699.1.1.8.1.5.1.1.2",
                    description => ".1.3.6.1.4.1.3699.1.1.8.1.5.1.1.3",
                    value => ".1.3.6.1.4.1.3699.1.1.8.1.5.1.1.7",
                    units => ".1.3.6.1.4.1.3699.1.1.8.1.5.1.1.9",
                    status => ".1.3.6.1.4.1.3699.1.1.8.1.5.1.1.10"
                }
            }, 
            digInputs => {
                num_sensors => 8,
                handler => \&interpret_sensor_response,
                type => 18, # hardcode a digital input sensor type
                check_oids => {
                    description => ".1.3.6.1.4.1.3699.1.1.8.1.6.1.1.3",
                    value => ".1.3.6.1.4.1.3699.1.1.8.1.6.1.1.7",
                    status => ".1.3.6.1.4.1.3699.1.1.8.1.6.1.1.8"
                }
            },        
       }
    },
    envSems2d => { 
        product_name => "ENVIROMUX-2D",
        sensors => {
            extSensors => {
                num_sensors => 4,
                handler => \&interpret_sensor_response,
                check_oids => {
                    type => ".1.3.6.1.4.1.3699.1.1.9.1.5.1.1.2",
                    description => ".1.3.6.1.4.1.3699.1.1.9.1.5.1.1.3",
                    value => ".1.3.6.1.4.1.3699.1.1.9.1.5.1.1.7",
                    units => ".1.3.6.1.4.1.3699.1.1.9.1.5.1.1.9",
                    status => ".1.3.6.1.4.1.3699.1.1.9.1.5.1.1.10"
                }
            }, 
            digInputs => {
                num_sensors => 6,
                handler => \&interpret_sensor_response,
                type => 18, # hardcode a digital input sensor type
                check_oids => {
                    description => ".1.3.6.1.4.1.3699.1.1.9.1.6.1.1.3",
                    value => ".1.3.6.1.4.1.3699.1.1.9.1.6.1.1.7",
                    status => ".1.3.6.1.4.1.3699.1.1.9.1.6.1.1.8"
                }
            },        
       }
    },
    ipdus2 => { 
        product_name => "IPDU-S2",
        sensors => {
            extSensors => {
                num_sensors => 4,
                handler => \&interpret_sensor_response,
                check_oids => {
                    type => ".1.3.6.1.4.1.3699.1.1.6.1.5.1.1.2",
                    description => ".1.3.6.1.4.1.3699.1.1.6.1.5.1.1.3",
                    value => ".1.3.6.1.4.1.3699.1.1.6.1.5.1.1.7",
                    units => ".1.3.6.1.4.1.3699.1.1.6.1.5.1.1.9",
                    status => ".1.3.6.1.4.1.3699.1.1.6.1.5.1.1.10"
                }
            },        
        }
    },
    enviromuxMini => { 
        product_name => "ENVIROMUX-MINI",
        snmp_version => "v1",
        sensor_offset => -1,
        sensors => {
           # The MINI doesn't put sensors in a table, each has their own OID.  
           # To allow integration into this script, we handle each sensor as 
           # its own sensor "class".
            temperatureSensor1 => {
                num_sensors => 1,
                handler => \&interpret_mini_sensor_response,
                check_oids => {
                    value => ".1.3.6.1.4.1.3699.1.1.3.1.1.1",
                    alert => ".1.3.6.1.4.1.3699.1.1.3.1.1.2",
                    description => ".1.3.6.1.4.1.3699.1.1.3.2.2.1",
                    units => ".1.3.6.1.4.1.3699.1.1.3.2.2.2"
                }
            },        
            temperatureSensor2 => {
                num_sensors => 1,
                handler => \&interpret_mini_sensor_response,
                check_oids => {
                    value => ".1.3.6.1.4.1.3699.1.1.3.1.2.1",
                    alert => ".1.3.6.1.4.1.3699.1.1.3.1.2.2",
                    description => ".1.3.6.1.4.1.3699.1.1.3.2.3.1",
                    units => ".1.3.6.1.4.1.3699.1.1.3.2.3.2"
                }
            },        
            humiditySensor1 => {
                num_sensors => 1,
                units => '%',
                handler => \&interpret_mini_sensor_response,
                check_oids => {
                    value => ".1.3.6.1.4.1.3699.1.1.3.1.3.1",
                    alert => ".1.3.6.1.4.1.3699.1.1.3.1.3.2",
                    description => ".1.3.6.1.4.1.3699.1.1.3.2.4.1",
                }
            },        
            humiditySensor2 => {
                num_sensors => 1,
                units => '%',
                handler => \&interpret_mini_sensor_response,
                check_oids => {
                    value => ".1.3.6.1.4.1.3699.1.1.3.1.4.1",
                    alert => ".1.3.6.1.4.1.3699.1.1.3.1.4.2",
                    description => ".1.3.6.1.4.1.3699.1.1.3.2.5.1",
                }
            },
            dryContact1 => {
                num_sensors => 1,
                handler => \&interpret_mini_digital_input_response,
                check_oids => {
                    value => ".1.3.6.1.4.1.3699.1.1.3.1.5.1",
                    alert => ".1.3.6.1.4.1.3699.1.1.3.1.5.2",
                    description => ".1.3.6.1.4.1.3699.1.1.3.2.6.1",
                }
            },        
            dryContact2 => {
                num_sensors => 1,
                handler => \&interpret_mini_digital_input_response,
                check_oids => {
                    value => ".1.3.6.1.4.1.3699.1.1.3.1.6.1",
                    alert => ".1.3.6.1.4.1.3699.1.1.3.1.6.2",
                    description => ".1.3.6.1.4.1.3699.1.1.3.2.7.1",
                }
            },
            dryContact3 => {
                num_sensors => 1,
                handler => \&interpret_mini_digital_input_response,
                check_oids => {
                    value => ".1.3.6.1.4.1.3699.1.1.3.1.7.1",
                    alert => ".1.3.6.1.4.1.3699.1.1.3.1.7.2",
                    description => ".1.3.6.1.4.1.3699.1.1.3.2.8.1",
                }
            },        
            dryContact4 => {
                num_sensors => 1,
                handler => \&interpret_mini_digital_input_response,
                check_oids => {
                    value => ".1.3.6.1.4.1.3699.1.1.3.1.8.1",
                    alert => ".1.3.6.1.4.1.3699.1.1.3.1.8.2",
                    description => ".1.3.6.1.4.1.3699.1.1.3.2.9.1",
                }
            },
            waterSensor => {
                num_sensors => 1,
                handler => \&interpret_mini_digital_input_response,
                check_oids => {
                    value => ".1.3.6.1.4.1.3699.1.1.3.1.9.1",
                    alert => ".1.3.6.1.4.1.3699.1.1.3.1.9.2",
                    description => ".1.3.6.1.4.1.3699.1.1.3.2.10.1",
                }
            },        
        }
    },
    enviromux16D => { 
        product_name => "ENVIROMUX-16D",
        sensors => {
            intSensors => {
                num_sensors => 3,
                handler => \&interpret_sensor_response,
                check_oids => {
                    type => ".1.3.6.1.4.1.3699.1.1.11.1.3.1.1.2",
                    description => ".1.3.6.1.4.1.3699.1.1.11.1.3.1.1.3",
                    value => ".1.3.6.1.4.1.3699.1.1.11.1.3.1.1.6",
                    units => ".1.3.6.1.4.1.3699.1.1.11.1.3.1.1.8",
                    status => ".1.3.6.1.4.1.3699.1.1.11.1.3.1.1.9"
                }
            },
            extSensors => {
                num_sensors => 32,
                handler => \&interpret_sensor_response,
                check_oids => {
                    type => ".1.3.6.1.4.1.3699.1.1.11.1.5.1.1.2",
                    description => ".1.3.6.1.4.1.3699.1.1.11.1.5.1.1.3",
                    value => ".1.3.6.1.4.1.3699.1.1.11.1.5.1.1.7",
                    units => ".1.3.6.1.4.1.3699.1.1.11.1.5.1.1.9",
                    status => ".1.3.6.1.4.1.3699.1.1.11.1.5.1.1.10"
                }
            }, 
            digInputs => {
                num_sensors => 8,
                handler => \&interpret_sensor_response,
                type => 18, # hardcode a digital input sensor type
                check_oids => {
                    description => ".1.3.6.1.4.1.3699.1.1.11.1.6.1.1.3",
                    value => ".1.3.6.1.4.1.3699.1.1.11.1.6.1.1.5",
                    status => ".1.3.6.1.4.1.3699.1.1.11.1.6.1.1.7"
                }
            },        
       }
    },
    enviromux5D => { 
        product_name => "ENVIROMUX-5D",
        sensors => {
            intSensors => {
                num_sensors => 2,
                handler => \&interpret_sensor_response,
                check_oids => {
                    type => ".1.3.6.1.4.1.3699.1.1.10.1.3.1.1.2",
                    description => ".1.3.6.1.4.1.3699.1.1.10.1.3.1.1.3",
                    value => ".1.3.6.1.4.1.3699.1.1.10.1.3.1.1.6",
                    units => ".1.3.6.1.4.1.3699.1.1.10.1.3.1.1.8",
                    status => ".1.3.6.1.4.1.3699.1.1.10.1.3.1.1.9"
                }
            },
            extSensors => {
                num_sensors => 10,
                handler => \&interpret_sensor_response,
                check_oids => {
                    type => ".1.3.6.1.4.1.3699.1.1.10.1.5.1.1.2",
                    description => ".1.3.6.1.4.1.3699.1.1.10.1.5.1.1.3",
                    value => ".1.3.6.1.4.1.3699.1.1.10.1.5.1.1.7",
                    units => ".1.3.6.1.4.1.3699.1.1.10.1.5.1.1.9",
                    status => ".1.3.6.1.4.1.3699.1.1.10.1.5.1.1.10"
                }
            }, 
            digInputs => {
                num_sensors => 6,
                handler => \&interpret_sensor_response,
                type => 18, # hardcode a digital input sensor type
                check_oids => {
                    description => ".1.3.6.1.4.1.3699.1.1.10.1.6.1.1.3",
                    value => ".1.3.6.1.4.1.3699.1.1.10.1.6.1.1.5",
                    status => ".1.3.6.1.4.1.3699.1.1.10.1.6.1.1.7"
                }
            },        
       }
    }
);



my %exit_codes=('OK'=>0, 'WARNING'=>1, 'CRITICAL'=>2, 'UNKNOWN'=>3, 'DEPENDENT'=>4);
my $Version='1.1';

my $o_host = undef;
my $o_community = undef;
my $o_help = undef;  
my $o_debug = undef;  
my $o_version = undef;
my $o_type = undef;
my $o_mode = undef;
my $o_index = undef;
my $o_class = undef;
my $timeout = 8;

# Catch the alarm signal
$SIG{'ALRM'} = sub {
     print ("ERROR: Alarm signal (Nagios time-out)\n");
     exit $exit_codes{"UNKNOWN"};
};

# Make sure Net::SNMP is available on the system
eval "use Net::SNMP";
if( $@ ) {
  print("ERROR: You do NOT have the Net:".":SNMP library \n"
  . "  Install it by running: \n"
  . "  perl -MCPAN -e shell \n"
  . "  cpan[1]> install Net::SNMP \n");
  exit 1;
}


check_options();

# SNMP Connection to the host
my ($session, $error);


################################################################################ 
# The user wants to run in configure mode
#
if( $o_mode eq "config" ) {
   debug("generate configuration");
   do_configuration();
   exit $exit_codes{"UNKNOWN"};
}


# Make sure that in case of failure, set an alarm in case 
alarm (20);

my $product = $systems{$o_type};

($session, $error) = Net::SNMP->session(
    -hostname  => $o_host,
    -version   => get_snmp_version_for_product($product),
    -community => $o_community,
    -timeout   => $timeout
);

if( !defined($session) ) {
	print ("UNKNOWN: SNMP error: $error\n");
	exit $exit_codes{'UNKNOWN'};
}

if( $o_mode eq "single" ) {
   my @ok;
   my @critical;
   my $output = '';

   my $perfdata = query_single_sensor($product, $o_class, $o_index, \@ok, \@critical);

   my $result = print_monitoring_output($output, $perfdata, \@ok, \@critical);

   cleanup($result);
}

if( $o_mode eq "batch" ) {
   debug("batch sensor query");
   my @status_ok;
   my @status_alert; 
   my $level = 0;
   my $output = "";
   my $perfdata = query_all_sensors_for_product($product, \@status_ok, \@status_alert);

   $level = print_monitoring_output($output, $perfdata, \@status_ok, \@status_alert);

   cleanup($level);
}


################################################################################ 
# Lookup the snmp version for a particular product.  If none is found in the
# definition, we default to v2c.
#
sub get_snmp_version_for_product {
   my $product = shift;
   my $snmp_version = "snmpv2c";

   if( defined($product->{"snmp_version"}) ) {
      $snmp_version = $product->{"snmp_version"};
   }

   return $snmp_version;
}


################################################################################ 
# Query a sensor based on the product, class, and index.  
#
sub query_single_sensor {
   my $product = shift;
   my $class = shift;
   my $index = shift;
   my $ok = shift;
   my $alert = shift;

   my %varlist = ();
   my $output = "";

   my %oids = get_sensor_oids($product, $class, $index); 
   my $res = $session->get_request( -varbindlist => [(values %oids)] );

   if( !defined($res) ) { 
      # @todo see if we need to handle this differently
      return $output;
   }

   for my $attr ( ( keys %oids) ) {
      debug("RESULT: $attr \n$oids{$attr} = $res->{$oids{$attr}}");
      $varlist{$attr} =  "$res->{$oids{$attr}}"; 
   }

   $varlist{index} = $index;
   $varlist{class} = $class;

   # call the registered handler for the sensor class to interpret the SNMP data
   return $product->{"sensors"}->{$class}->{"handler"}->(\%varlist, $ok, $alert, $product->{"sensors"}->{$class});
}


################################################################################ 
# Look up the OIDs to query for a given product, class, and index.
#
sub get_sensor_oids {
   my $product = shift;
   my $class = shift;
   my $index = shift;
   my %oids = ();
   my $sensor_offset = 0;

   if( defined($product->{"sensor_offset"}) ) {
      $sensor_offset = $product->{"sensor_offset"};
   }

   my $class_info = $product->{"sensors"}{$class};
   if( $index > $class_info->{"num_sensors"} or $index < 1 ) {
      print "Index $index out of valid sensor range (1-" . $class_info->{"num_sensors"} . ")\n"; 
      exit $exit_codes{"UNKNOWN"};
   }

   while (my ($name, $oid) = each( %{$class_info->{"check_oids"}})) {
      debug("Adding $name:$oid");
      $oids{$name} = $oid . "." . ($index + $sensor_offset);
   }
   return %oids;
}


################################################################################ 
# Interpret the SNMP response for the sensor and generate NAGIOS friendly data
#
sub interpret_sensor_response {
   my $vars = shift;
   my $ok = shift;
   my $alert = shift;
   my $sensor_info = shift;

   my $class = $vars->{class};
   my $index = $vars->{index};
   my $type = $vars->{type};
   my $description = $vars->{description};
   my $value = $vars->{value};
   my $units = $vars->{units};
   my $status = $vars->{status};

   my $divisor = 1.0;

   # A sensor with a type of zero means that there is no sensor in the slot.  The sensor class
   # may pass us a fixed type to use (such as for digital inputs).  We check for existence of
   # this and if we still don't have a type, we bail.
   if( !defined($type) or $type == 0 ) {
      $type = $sensor_info->{'type'};

      return "" unless ($type);
   }

   # Some sensors are presents as x10, some are x10000.  We need to reconstruct
   # the appropriate value, so we pick out the appropriate divisor for the type
   if( $type == 1 or $type == 3 or $type == 5 or $type == hex("8001") or
        $type == 6 or $type == 8 ) {
      $divisor = 10.0;
   }
   elsif( $type == 4 or $type == hex("0404")) {
      $divisor = 10000.0;
   }

   $value = $value / $divisor;

   if( $type >= 9 and $type <=18 ) {
      if( $value == "0.0" ) {
         $units = "Closed";

      } else {
         $units = "Open";
      }
   }

   my %output = ( description => $description, 
                  value => $value, 
                  units => $units, 
                  class => $class, 
                  index => $index);

   if( $status == 3 or $status == 6 or $status == 7 ) {
      push(@$alert, \%output);

   } else {
      push(@$ok, \%output);
   }

   # Now retrn the performance data for this sensor
   $description =~ s/ /_/g;
   return "$description=$value$units;;;; ";
}


################################################################################ 
# Interpret the SNMP response for the sensor and generate NAGIOS friendly data
#
sub interpret_mini_sensor_response {
   my $vars = shift;
   my $oks = shift;
   my $alerts = shift;

   my $class = $vars->{class};
   my $index = $vars->{index};
   my $description = $vars->{description};
   my $value = $vars->{value};
   my $units = $vars->{units};
   my $alert = $vars->{alert};

   my $divisor = 10.0;

   $units = "%" unless($units);

   $value = $value / $divisor;

   my %output = ( description => $description, 
                  value => $value, 
                  units => $units, 
                  class => $class, 
                  index => $index);

   if( $alert == 1 ) {
      push(@$alerts, \%output);

   } else {
      push(@$oks, \%output);
   }

   # Now retrn the performance data for this sensor;
   $description =~ s/ /_/g;
   return "$description=$value$units;;;; ";
}


################################################################################ 
# Interpret a digital input response from an ENVIROMUX-MINI
#
sub interpret_mini_digital_input_response {
   my $vars = shift;
   my $oks = shift;
   my $alerts = shift;
   my $sensor_info = shift;

   my $description = $vars->{description};
   my $class = $vars->{class};
   my $index = $vars->{index};
   my $value = $vars->{value};
   my $alert = $vars->{alert};

   my $units;

   if( $value == "0" ) {
      $units = "Open";

   } else {
      $units = "Closed";
   }

   my %output = ( description => $description, 
                  value => $value, 
                  units => $units, 
                  class => $class, 
                  index => $index);

   if( $alert == 1 ) {
      push(@$alerts, \%output);

   } else {
      push(@$oks, \%output);
   }

   # Now retrn the performance data for this sensor;
   $description =~ s/ /_/g;
   return "$description=$value$units;;;; ";
}


################################################################################ 
# Build and print a suitable output for nagios.  The output is constructed from
# two arrays and performance data.  If we have any critical items, our entire
# run is considered "CRITICAL" for nagios.  
#
# The resuling output looks as follows:
# CRITICAL - crit1: value, crit2: value OK - ok1: value |performance data
sub print_monitoring_output {
   my $output = shift;
   my $perfdata = shift;
   my $ok = shift;
   my $alerts = shift;
   my $level = 0;
   my $items_found = 0;

   if( scalar(@$alerts) > 0 ) {
      $output .= 'CRITICAL - ';
      my $i = 0;
      foreach my $alert (@$alerts) {
         $output .= ',' if( $i++ );
         $output .= ' ' . $alert->{description} . ' ' . $alert->{value} . $alert->{units} ; 
         $items_found++;
      }
   
      $output .= ' '; 
      $level = 2;
   }

   if( scalar(@$ok) > 0 ) {
      $output .= 'OK - ';
      my $i = 0;
      foreach my $normal (@$ok) {
         $output .= ', ' if( $i++ );
         $output .= $normal->{description} . ' ' . $normal->{value} . $normal->{units} ; 
         $items_found++;
      }
   }

   if( !$items_found ) {
      print "ERROR - unable to acquire sensor data!\n";
      $level = 3;

   } else {
      print "$output |$perfdata \n";
   }

   return $level;
}


################################################################################ 
# Make sure we close the SNMP session and return the proper exit status
#
sub cleanup {
   my $exit_status = shift;

   $session->close();
   exit $exit_status;
}


################################################################################ 
# Get a list of products from the systems hash.
#
# Returns an array formatted as follows:
# array[i] = {
#              model => "model name",
#              name => "product name"
#            }
sub get_list_of_products {
   my @products = ();

   foreach my $product (sort (keys %systems) ) {
      push @products, {name => $systems{$product}{"product_name"}, model => $product};
   }

   return @products;
}


################################################################################ 
# Generate a "host" configuration for the specified unit.
#
sub print_host_config {
   my $product = shift;
   my $host = shift;
   my $community = shift;

print <<'COMMANDEND';

# You need to define this command exactly once to monitor NTI products.
# define command{
#       command_name    check_nti_snmp
#       command_line    $USER1$/check_nti_snmp.pl -H $HOSTADDRESS$ $ARG1$
#       }
#

COMMANDEND

print <<CONFIGEND;
define host{
        use                    generic-host
        host_name              $product->{model}_$host
        alias                  $product->{name} $host 
        address                $host
        max_check_attempts     5
        }
CONFIGEND
}


################################################################################ 
# Generate a "batch" configuration for the specified unit.
#
sub print_batch_config {
   my $product = shift;
   my $host = shift;
   my $community = shift;

print <<CONFIGEND;

define service{
        use                    generic-service
        host_name              $product->{model}_$host
        service_description    ALL_SENSORS
        check_command          check_nti_snmp!-m batch -C $community -p $product->{model}
        }
CONFIGEND
}


################################################################################ 
# Generate a configuration for the specified sensor.
#
sub print_sensor_config {
   my $product = shift;
   my $sensor = shift;
   my $host = shift;
   my $community = shift;

   my $description = $sensor->{description};
   my $class = $sensor->{class};
   my $index = $sensor->{index};

print <<CONFIGEND;

define service{
        use                    generic-service
        host_name              $product->{model}_$host
        service_description    $description
        check_command          check_nti_snmp!-m single -C $community -p $product->{model} -L $class -i $index
        }
CONFIGEND
}


################################################################################ 
# Assist the user in generating a proper configuration for nagios.
#
sub do_configuration {
   my $done = 0;
   my @products = get_list_of_products();

   while (! $done) {
      my $host;
      my $community;
      my $mode;
      my $product_type;
      my $i = 1;

      print "What product type are we configuring for Nagios?\n";
      foreach my $p (@products) {
            print "\t$i) " . $p->{name} . "\n";
            $i++;
      }
      print "Enter choice [1]: ";
      chomp($product_type = <STDIN>);
      if( !$product_type ) { $product_type = 1;}

      print "Enter the IP address of the device: ";
      chomp($host = <STDIN>);


      print "Enter the SNMP community string [public]: ";
      chomp($community = <STDIN>);
      if( !$community ) { $community = "public";}

      print "Which type of service to generate?\n";
      print "\t1) One service for the entire device\n";
      print "\t2) One service for each sensor\n";
      print "Enter choice [1]: ";
      chomp($mode = <STDIN>);

      if( !$mode ) { $mode = 1; }

      if( $mode == 1 ) {
         # generate a batch configuration.  We don't actually connect to the
         # device via SNMP for this, we just use the product definitions.
         print_host_config $products[$product_type - 1], $host, $community;
         print_batch_config $products[$product_type - 1], $host, $community;

      } else {
         $product = $systems{$products[$product_type-1]->{model}};
         
         # we need to actually connect to the unit and query sensor settings.
         ($session, $error) = Net::SNMP->session(
            -hostname  => $host,
            -version   => get_snmp_version_for_product($product),
            -community => $community,
            -timeout   => $timeout
            );

         if( !defined($session) ) {
            print ("UNKNOWN: SNMP error: $error\n");
            exit $exit_codes{'UNKNOWN'};
         }

         my @status_ok;
         my @status_alert; 
         my $level = 0;
         my $output = "";

         query_all_sensors_for_product($product, \@status_ok, \@status_alert);

         # add all sensors to one list so we can process them
         push @status_ok, @status_alert;

         generate_sensor_configs($products[$product_type-1], \@status_ok, $host, $community);
      }

      $done = 1;
   }
}


################################################################################ 
# Iterate over each of the sensors and generate its configuration for use in 
# nagios.
#
sub generate_sensor_configs {
   my $output = "";
   my $product = shift;
   my $sensors = shift;
   my $host = shift;
   my $community = shift;

   print_host_config $product, $host, $community;

   if( scalar(@$sensors) > 0 ) {
      foreach my $sensor (@$sensors) {
         print_sensor_config($product, $sensor, $host, $community);
      }
   }

   return 0;
}


################################################################################ 
# Iterate over each of the sensors and query it's data.  
#
sub query_all_sensors_for_product {
   debug("create config for each sensor");
   my $product = shift;
   my $status_ok = shift;
   my $status_alert = shift; 

   my $perfdata = "";

   while (my ($class, $class_data) = each( %{$product->{"sensors"}})) {
      my $num_sensors_for_class = $class_data->{"num_sensors"};
      for(my $index = 1; $index <= $num_sensors_for_class; $index++) {
         $perfdata .= query_single_sensor($product, $class, $index, $status_ok, $status_alert);
      }
   }

   return $perfdata;
}


################################################################################ 
# Print out script version information.
#
sub print_version { print basename($0) . ": $Version" };


################################################################################ 
# Print out usage information
#
sub print_usage {
   my $script_name = basename($0);
   print "Usage: $script_name [-v] [-h] -H <host> -C <snmp_community> -m <mode> -p <product> [-L <sensor_class>] [-i <sensor_index>] \n";
}


################################################################################ 
# Show more verbose help output.
#
sub help {
   my $products_classes = "";

   print "\nNetwork Technologies Inc Nagios Monitor version ", $Version, "\n";
   print_usage();
   
   print "\nScript supports the following Network Technologies Inc products:\n";

   my $spacer = "\n            ";
   foreach my $product (sort (keys %systems) ) {
      print "\t" . $systems{$product}{"product_name"} . " (" . $product .")\n";
      $products_classes .= "        " . $product . ": $spacer" . join($spacer, sort keys(%{$systems{$product}{sensors}})) . "\n";
   }
   print "\n";
   
   my $products_supported = join('|', sort keys %systems);


    print <<EOD;
-h, --help
        print this help message
-H, --hostname=HOST
        name or IP address of device to query
-C, --community=COMMUNITY NAME
        community name for the device's SNMP agent
-m, --mode=MODE
        Specify the script mode (single, batch, config)
-p, --product=$products_supported
        Specify the product type being monitored
-L, --class=CLASS
        Specify the sensor class 
$products_classes
-i, --index=INDEX
        Specify the index of the sensor to query
-v, --version
        prints version number

EOD
}


################################################################################ 
# For debugging output
#
sub debug { my $t=shift; print $t,"\n" if defined($o_debug) ; }


################################################################################ 
# Make sure the user specifies valid options to the script
#
sub check_options {
   my $result = 0;
   Getopt::Long::Configure ("bundling");
   GetOptions(
      'V'    => \$o_debug,       'verbose'     => \$o_debug,
      'h'    => \$o_help,        'help'        => \$o_help,
      'H:s'  => \$o_host,        'hostname:s'  => \$o_host,
      'C:s'  => \$o_community,   'community:s' => \$o_community,
      'v'    => \$o_version,     'version'     => \$o_version,
      'p:s'  => \$o_type,        'product:s'   => \$o_type,
      'L:s'  => \$o_class,       'class:s'     => \$o_class,
      'i:s'  => \$o_index,       'index:s'     => \$o_index,
      'm:s'  => \$o_mode,        'mode:s'      => \$o_mode
      );
   
   if( defined($o_help) ) { 
      help(); 
      exit $exit_codes{"UNKNOWN"};
   }
   
   if( defined($o_version) ) { 
      print_version(); 
      exit $exit_codes{"UNKNOWN"};
   }
   
   if( !defined($o_mode) ) { 
      print "Please specify a mode!\n"; 
      exit_error_with_usage();
   }
   
   if( !($o_mode eq "config") ) {

      # A few parameters are required for both batch and single sensor queries.
      if( !defined($o_host) ) { 
         print "No host defined!\n"; 
         exit_error_with_usage();
      }

      if( !defined($o_community) ) { 
         print "No SNMP community defined\n"; 
         exit_error_with_usage();
      }
      
      if( !defined($o_type) ) { 
         print "Must define the product!\n"; 
         exit_error_with_usage();
      }
      
      if( !defined($systems{$o_type}) ) { 
         print "Unknown product $o_type\n"; 
         exit_error_with_usage();
      }

      # Additionally, single sensor queries require a few more parameters
      if( $o_mode eq "single" ) {

         if( !defined($o_class) ) { 
            print "Sensor class must be defined\n";  
            exit_error_with_usage();
         }
         
         if( !defined($o_index) ) { 
            print "Sensor index must be defined\n"; 
            exit_error_with_usage();
         }
         
         if( !defined($systems{$o_type}{"sensors"}{$o_class}) ) { 
            print "Unknown sensor class $o_class\n"; 
            exit_error_with_usage();
         }
      }
   }
}  


################################################################################ 
# Simple wrapper to exit with error code and show usage information.
#
sub exit_error_with_usage {
   print_usage();
   exit $exit_codes{"UNKNOWN"};
}
