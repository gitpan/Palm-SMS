# SMS.pm
#
# Perl module for reading, manipulating, and writing the .pdb files
# used by Handspring SMS application on PalmOS devices such as
# Handspring Treo 270.
#
# This code is provided "as is" with no warranty.  The exact terms
# under which you may use and (re)distribute it are detailed
# in the GNU General Public License, in the file COPYING.
#
# Copyright (C) 2005 Free Software Foundation, Inc.
#
# Written by Lorenzo Cappelletti <lorenzo.cappelletti@email.it>
#
#
# $Id: SMS.pm,v 1.3 2005/01/02 10:23:15 lolo Exp $

package Palm::SMS;

use strict;
use warnings;
use Palm::Raw();
use vars qw($VERSION @ISA @folders);

$VERSION = 0.01;

@ISA = qw(Palm::Raw);

=head1 NAME

Palm::SMS - parse SMS database files

=head1 SYNOPSIS

    use Palm::PDB;
    use Palm::SMS;

    my $pdb = new Palm::PDB;
    $pdb->Load("sms.pdb");

    my $record = $pdb->{records}[0];
    print "$record->{text}\n";

=head1 DESCRIPTION

The SMS PDB handler is a helper class for the Palm::PDB module.  It is
intended for reading, manipulating, and writing the .pdb files used by
Handspring SMS application on PalmOS devices such as Handspring Treo
270.

Palm::SMS module is the result of a reverse engineering attempt of
trasforming a Handspring Treo 270 SMS PDB file into a plain text file.
The PDB test file was produced by Handspring's application SMS
v. 3.5H.

Due to lack of knowledge about how PDB files work and what format SMS
database files conform to, at present this module is not suitable for
from-scratch SMS generation.  Conversely, you may find it extremely
useful if you intend to extract SMS messages from merged PDB files and
convert them to a human readable form.

=head2 Fields

    $record = $pdb->{records}[N];

    $record->{name}
    $record->{firstName}
    $record->{phone}
    $record->{folder}
    $record->{timestamp}
    $record->{text}

    $record->{smsh}
    $record->{unknown1}
    $record->{unknown2}
    $record->{unknown3}

The fields provided for each record are the following:

=over

=item name

A string containing the name of the person who wrote the message.

=item firstname

A string containing the first name of the person who wrote the
message.

=item phone

A string containing the phone number.

=item timestamp

An integer which represents the number of seconds elapsed from Unix
epoch to message creation time.

It is worth noticing that there is no way of retrieving neither the TZ
nor the DST out of data stored in the PDB file.  This timestamp always
expresses the time of your handheld's clock at message creation time.
Hence, I suggest passing the value C<GMT> as third argument to
L<Date::Format>'s time2str() to get the right timestamp
rappresentation:

  use Date::Format;
  ...
  $timestamp = time2str( "%T", $record->{timestamp}, "GMT")
             . time2str(" %Z", $record->{timestamp}       );

=item folder

An integer which represents in which folder the message was stored.
English folder names (such as I<Inbox> or I<Sent>) are available as

  $Palm::SMS::folders[$record->{folder}];

=item text

A string containing the message body.

=back

The module provides additional fields which will probably be less
commonly used.

=over

=item smsh

This string of four bytes ("I<SMSh>") is present at the start of each
record.

=item unknown1

=item unknown2

=item unknown3

These fields contain a chunk of bytes whose function is not yet known.
Please, refer to the L<ParseRecord()|/"ParseRecord"> method.

=back

=head1 METHODS

=cut
#'

@folders = (                            # SMS folder names
  "Inbox",
  "Sent",
  "Pending",  # guessed
);

my $EPOCH_1904 = 2082844800;            # Difference between Palm's
                                        # epoch (Jan. 1, 1904) and
                                        # Unix's epoch (Jan. 1, 1970),
                                        # in seconds.

sub import {
  &Palm::PDB::RegisterPDBHandlers(__PACKAGE__,
                                  [ "SMS!", "DATA" ],
                                 );
}

=head2 new

  $pdb = new Palm::SMS;

Creates a new PDB, initialized with the various Palm::SMS fields
and an empty record list.

Use this method if you're creating a SMS PDB from scratch.

=cut
#'
sub new {
  my $classname = shift;
  my $self = $classname->SUPER::new(@_); # no need to rebless
  $self->{name} = "SMS Messages"; # default
  $self->{creator} = "SMS!";
  $self->{type} = "DATA";
  $self->{attributes}{resource} = 0; # not a resource db


  $self->{sort} = undef; # empty sort block

  $self->{records} = []; # empty list of records

  return $self;
}

=head2 new_Record

  $record = $pdb->new_Record;

  $record->{phone}  = "1234567890";
  $record->{folder} = 1;
  ...

  $phone  = $record->{phone};
  $folder = $Palm::SMS::folders[$record->{folder}];
  ...

Creates a new SMS record, with blank values for all of the fields.

C<new_Record> does B<not> add the new record to C<$pdb>. For that,
you want C<$pdb-E<gt>append_Record>.

Default field values are:

  name     : undef
  firstName: undef
  phone    : undef
  timestamp: localtime()
  folder   : 1
  text     : undef

  smsh     : "SMSh"
  unknown1 : undef
  unknown2 : undef
  unknown3 : undef

=cut

sub new_Record {
  my $classname = shift;
  my $retval = $classname->SUPER::new_Record(@_);

  $retval->{name}       = undef;
  $retval->{firstName}  = undef;
  $retval->{phone}      = undef;
  $retval->{timestamp}  = localtime;
  $retval->{folder}     = 1;
  $retval->{text}       = undef;

  $retval->{smsh}       = "SMSh";
  $retval->{unknown1}   = undef;
  $retval->{unknown2}   = undef;
  $retval->{unknown2}   = undef;

  return $retval;
}

=head2 ParseRecord

ParseRecord() returns a parsed representation of the record, typically
as a reference to a record object or anonymous hash.  It is
automatically called from within L<Palm::PDB(3)> and, as such, is not
intented to be used directly from applications.

The record structure which an SMS posses is:

    smsh     :  4-byte ASCII string
    unknown1 :  2-byte data whose function is unknown
    timestamp:  32-bit, big-endian, unsigned integer rappresenting
                the number of seconds since 1904
    unknown2 :  26-byte data whose function is unknown
    phone    :  Null terminated string
    name     :  Null terminated string
    firstname:  Null terminated string
    unknown3 :  16-byte data whose function is unknown
    text     :  Null terminated (sent messages only) string

I<folder> field value is copied from I<category> field which is
computed by Palm::PDB and then delted since there is no application
info block (see L<Palm::StdAppInfo(3)>) in the PDB file.

I<unknown3> is empty for messages belonging to category 1 (folder
I<Sent>).

It is worth noticing that length, offset, and even availability of
I<unknown> data are not preserved between module version when their
meaning becomes clear.

=cut

sub ParseRecord {
  my $self = shift;
  my %record = @_;
  my @unpack;

  my $smsh;       # each record starts with "SMSh": SMS handler?
  my $unknown1;
  my $timestamp;
  my $unknown2;
  my $name;
  my $firstName;
  my $unknown3;
  my $phone;
  my $folder;
  my $text;

  if ($record{category} == 0) {
    ### Inbox folder ###
    my $nameFlag;       # whether name and firstName are available
    my $extra;          # temporary string

    ($smsh,
     $unknown1,
     $timestamp,
     $unknown2,
     $phone,
     $extra,
    ) = unpack("A4 a2 N a26 Z* a*", $record{data});

    # unknown2 tells whether name and firstName are available
    $nameFlag = unpack("x7 H", $unknown2);
    if ($nameFlag eq "4") {
      ($name,
       $firstName,
       $extra,
      ) = unpack("Z* Z* a*", $extra);
    }

    # $extra's head contains unknown3 followed by "\d\0"
    ($unknown3, $text) = $extra =~ m/(.*?\d\0)([^\0]+)$/;

  } elsif ($record{category} == 1) {
    ### Sent folder ###
    my $unpack;

    ($smsh,
     $unknown1,
     $timestamp,
     $unknown2,
     $phone,
     $name,
     $firstName,
     $text,
    ) = unpack("A4 a2 N a26 Z* Z* Z* Z*", $record{data});
    $unknown3 = "";

  } elsif ($record{category} == 2) {
    ### Pending folder ###
    die "Never tried to parse a message from Pending folder";

  } else {
    die "Unknown category";

  }

  # Work out common extracted values
  $timestamp -= $EPOCH_1904;

  # Assign extracted values to record
  $record{name}      = $name;
  $record{firstName} = $firstName;
  $record{phone}     = $phone;
  $record{timestamp} = $timestamp;
  $record{folder}    = $record{category};
  $record{text}      = $text;

  $record{smsh}      = $smsh;
  $record{unknown1}  = $unknown1;
  $record{unknown2}  = $unknown2;
  $record{unknown3}  = $unknown3;

  delete $record{data};

  return \%record;
}

=head2 PackRecord

This is the converse of L<ParseRecord()|/ParseRecord>. PackRecord()
takes a record as returned by ParseRecord() and returns a string of
raw data that can be written to the database file.  As
L<ParseRecord()|/ParseRecord>, this function is not intended to be
used directly from applications.

Because there are chunk of record data whose function is unknown (see
L<ParseRecord()|/ParseRecord>), this method may produce an invalid
result, expecially when passed record was created from scratch via
L<new_Record()/new_Record>.

This method is granted to work if the record being packed has been
unpacked from an existing PDB and no information has been added.

=cut

sub PackRecord {
  my $self = shift;
  my $record = shift;
  my $retval;
  my $pack;

  $pack = "A4 a2 N a26 Z*";

  if ($record->{folder} == 0) {
    ### Inbox folder ###
    if (not ($record->{name} or $record->{firstName})) {
      $pack .= " a* A*";
      $retval = pack($pack,
                     $record->{smsh},
                     $record->{unknown1},
                     $record->{timestamp} + $EPOCH_1904,
                     $record->{unknown2},
                     $record->{phone},
                     $record->{unknown3},
                     $record->{text});

    } else {
      $pack .= " Z* Z* a* A*";
      $retval = pack($pack,
                     $record->{smsh},
                     $record->{unknown1},
                     $record->{timestamp} + $EPOCH_1904,
                     $record->{unknown2},
                     $record->{phone},
                     $record->{name},
                     $record->{firstName},
                     $record->{unknown3},
                     $record->{text});

    }

  } elsif ($record->{folder} ==1) {
    ### Sent folder ###
    $pack .= " Z* Z* Z*";
      $retval = pack($pack,
                     $record->{smsh},
                     $record->{unknown1},
                     $record->{timestamp} + $EPOCH_1904,
                     $record->{unknown2},
                     $record->{phone},
                     $record->{name},
                     $record->{firstName},
                     $record->{text});

  } elsif ($record->{folder} == 2) {
    ### Pending folder ###
    die "Never tried to pack a message to Pending folder";

  } else {
    die "Unknown category";

  }

  return $retval;
}

1;
__END__

=head1 BUGS

Not all data chunks have a known function.  Hence, the module is
suitable only for data extraction and simple database manipulations.

I heard rumors that SMS format changes with GSM network providers.
Please, contact me if this module cannot correctly handle your
messages, hopefully attaching a patch which corrects the shortcoming.

=head1 SEE ALSO

L<Palm::PDB(3)> by Andrew Arensburger E<lt>arensb@ooblick.comE<gt>

L<smssync(1)> v 1.0 by Janne Mäntyharju E<lt>janne.mantyharju@iki.fiE<gt>

=head1 AUTHOR

Lorenzo Cappelletti E<lt>lorenzo.cappelletti@email.itE<gt>

=head1 COPYRIGHT AND DISCLAIMER

This program is Copyright 2005 by Lorenzo Cappelletti.  This program
is free software; you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free
Software Foundation, either version 2 of the License, or (at your
option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111, USA.

=cut
