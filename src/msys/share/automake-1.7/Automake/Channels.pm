# Copyright (C) 2002 Free Software Foundation, Inc.

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
# 02111-1307, USA.

package Automake::Channels;

=head1 NAME

Automake::Channels - support functions for error and warning management

=head1 SYNOPSIS

  use Automake::Channels;

  # Register a channel to output warnings about unused variables.
  register_channel 'unused', type => 'warning';

  # Register a channel for system errors.
  register_channel 'system', type => 'error', exit_code => 4;

  # Output a message on channel 'unused'.
  msg 'unused', "$file:$line", "unused variable `$var'";

  # Make the 'unused' channel silent.
  setup_channel 'unused', silent => 1;

  # Turn on all channels of type 'warning'.
  setup_channel_type 'warning', silent => 0;

  # Treat all warnings as errors.
  $warnings_are_errors = 1;

  # Exit with the greater exist code encountered so far.
  exit $exit_code;

=head1 DESCRIPTION

This perl module provides support functions for handling diagnostic
channels in programs.  Channels can be registered to convey fatal,
error, warning, or debug messages.  Each channel has various options
(e.g. is the channel silent, should duplicate messages be removed,
etc.) that can also be overridden on a per-message basis.

=cut

use 5.005;
use strict;
use Exporter;
use Carp;
use File::Basename;

use vars qw (@ISA @EXPORT %channels $me);

@ISA = qw (Exporter);
@EXPORT = qw ($exit_code $warnings_are_errors
	      &reset_local_duplicates &reset_global_duplicates
	      &register_channel &msg &exists_channel &channel_type
	      &setup_channel &setup_channel_type
	      &dup_channel_setup &drop_channel_setup
	      &buffer_messages &flush_messages
	      US_GLOBAL US_LOCAL
	      UP_NONE UP_TEXT UP_LOC_TEXT);

$me = basename $0;

=head2 Global Variables

=over 4

=item C<$exit_code>

The greatest exit code seen so far. C<$exit_code> is updated from
the C<exit_code> options of C<fatal> and C<error> channels.

=cut

use vars qw ($exit_code);
$exit_code = 0;

=item C<$warnings_are_errors>

Set this variable to 1 if warning messages should be treated as
errors (i.e. if they should update C<$exit_code>).

=cut

use vars qw ($warnings_are_errors);
$warnings_are_errors = 0;

=back

=head2 Constants

=over 4

=item C<UP_NONE>, C<UP_TEXT>, C<UP_LOC_TEXT>

Possible values for the C<uniq_part> options.  This select the part
of the message that should be considered when filtering out duplicates.
If C<UP_LOC_TEXT> is used, the location and the explanation message
are used for filtering.  If C<UP_TEXT> is used, only the explanation
message is used (so the same message will be filtered out if it appears
at different locations).  C<UP_NONE> means that duplicate messages
should be output.

=cut

use constant UP_NONE => 0;
use constant UP_TEXT => 1;
use constant UP_LOC_TEXT => 2;

=item C<US_LOCAL>, C<US_GLOBAL>

Possible values for the C<uniq_scope> options.
Use C<US_GLOBAL> for error messages that should be printed only
once in the run of the program, C<US_LOCAL> for message that
should be printed only once per file.  (Actually, C<Channels> does not
now when files are changed, it relies on you calling C<reset_local_duplicates>
when this happens.)

=cut

# possible values for uniq_scope
use constant US_LOCAL => 0;
use constant US_GLOBAL => 1;

=back

=head2 Options

Channels accept the options described below.  These options can be
passed as a hash to the C<register_channel>, C<setup_channel>, and C<msg>
functions.  The possible keys, with there default value are:

=over

=item C<type =E<gt> 'warning'>

The type of the channel.  One of C<'debug'>, C<'warning'>, C<'error'>, or
C<'fatal'>.  Fatal messages abort the program when they are output.
Error messages update the exit status.  Debug and warning messages are
harmless, except that warnings can be treated as errors of
C<$warnings_are_errors> is set.

=item C<exit_code =E<gt> 1>

The value to update C<$exit_code> with when a fatal or error message
is emited.  C<$exit_code> is also updated for warnings output
when @<$warnings_are_errors> is set.

=item C<file =E<gt> \*STDERR>

The file where the error should be output.

=item C<silent =E<gt> 0>

Whether the channel should be silent.  Use this do disable a
category of warning, for instance.

=item C<uniq_part =E<gt> UP_LOC_TEXT>

The part of the message subject to duplicate filtering.  See the
documentation for the C<UP_NONE>, C<UP_TEXT>, and C<UP_LOC_TEXT>
constants above.

=item C<uniq_scope =E<gt> US_LOCAL>

The scope of duplicate filtering.  See the documentation for the
C<US_LOCAL>, and C<US_GLOBAL> constants above.

=item C<header =E<gt> ''>

A string to prepend to each message emitted through this channel.

=item C<footer =E<gt> ''>

A string to append to each message emitted through this channel.

=item C<backtrace =E<gt> 0>

Die with a stack backtrace after displaying the message.

=back

=cut

use vars qw (%_default_options %_global_duplicate_messages
	     %_local_duplicate_messages);

# Default options for a channel.
%_default_options =
  (
   type => 'warning',
   exit_code => 1,
   file => \*STDERR,
   silent => 0,
   uniq_scope => US_LOCAL,
   uniq_part => UP_LOC_TEXT,
   header => '',
   footer => '',
   backtrace => 0,
   );

# Filled with output messages as keys, to detect duplicates.
# The value associated to each keys is the number of occurences
# filtered out.
%_local_duplicate_messages = ();
%_global_duplicate_messages = ();

sub _reset_duplicates (\%)
{
  my ($ref) = @_;
  my $dup = 0;
  foreach my $k (keys %$ref)
    {
      $dup += $ref->{$k};
    }
  %$ref = ();
  return $dup;
}


=head2 Functions

=over 4

=item C<reset_local_duplicates ()>

Reset local duplicate messages (see C<US_LOCAL>), and
return the number of messages that have been filtered out.

=cut

sub reset_local_duplicates ()
{
  return _reset_duplicates %_local_duplicate_messages;
}

=item C<reset_global_duplicates ()>

Reset local duplicate messages (see C<US_GLOBAL>), and
return the number of messages that have been filtered out.

=cut

sub reset_global_duplicates ()
{
  return _reset_duplicates %_global_duplicate_messages;
}

sub _merge_options (\%%)
{
  my ($hash, %options) = @_;
  local $_;

  foreach (keys %options)
    {
      if (exists $hash->{$_})
	{
	  $hash->{$_} = $options{$_}
	}
      else
	{
	  confess "unknown option `$_'";
	}
    }
}

=item C<register_channel ($name, [%options])>

Declare channel C<$name>, and override the default options
with those listed in C<%options>.

=cut

sub register_channel ($;%)
{
  my ($name, %options) = @_;
  my %channel_opts = %_default_options;
  _merge_options %channel_opts, %options;
  $channels{$name} = \%channel_opts;
}

=item C<exists_channel ($name)>

Returns true iff channel C<$name> has been registered.

=cut

sub exists_channel ($)
{
  my ($name) = @_;
  return exists $channels{$name};
}

=item C<channel_type ($name)>

Returns the type of channel C<$name> if it has been registered.
Returns The empty string otherwise.

=cut

sub channel_type ($)
{
  my ($name) = @_;
  return $channels{$name}{'type'} if exists_channel $name;
  return '';
}

# _format_message ($LEADER, $MESSAGE)
# -----------------------------------
# Split $MESSAGE at new lines and add $LEADER to each line.
sub _format_message ($$)
{
  my ($leader, $message) = @_;
  return $leader . join ("\n" . $leader, split ("\n", $message)) . "\n";
}

# _print_message ($LOCATION, $MESSAGE, %OPTIONS)
# ----------------------------------------------
# Format the message, check duplicates, and print it.
sub _print_message ($$%)
{
  my ($location, $message, %opts) = @_;

  return 0 if ($opts{'silent'});

  if ($location)
    {
      $location .= ': ';
    }
  else
    {
      $location = "$me: ";
    }

  my $msg = _format_message ($location,
			     $opts{'header'} . $message . $opts{'footer'});

  # Check for duplicate message if requested.
  if ($opts{'uniq_part'} != UP_NONE)
    {
      # Which part of the error should we match?
      my $to_filter;
      if ($opts{'uniq_part'} == UP_TEXT)
	{
	  $to_filter = $message;
	}
      elsif ($opts{'uniq_part'} == UP_LOC_TEXT)
	{
	  $to_filter = $msg;
	}
      else
	{
	  confess "unknown value for uniq_part: " . $opts{'uniq_part'};
	}

      # Do we want local or global uniqueness?
      my $dups;
      if ($opts{'uniq_scope'} == US_LOCAL)
	{
	  $dups = \%_local_duplicate_messages;
	}
      elsif ($opts{'uniq_scope'} == US_GLOBAL)
	{
	  $dups = \%_global_duplicate_messages;
	}
      else
	{
	  confess "unknown value for uniq_scope: " . $opts{'uniq_scope'};
	}

      # Update the hash of messages.
      if (exists $dups->{$to_filter})
	{
	  ++$dups->{$to_filter};
	  return 0;
	}
      else
	{
	  $dups->{$to_filter} = 0;
	}
    }
  my $file = $opts{'file'};
  print $file $msg;
  return 1;
}

=item C<msg ($channel, $location, $message, [%options])>

Emit a message on C<$channel>, overriding some options of the channel  with
those specified in C<%options>.  Obviously C<$channel> must have been
registered with C<register_channel>.

C<$message> is the text of the message, and C<$location> is a location
associated to the message.

For instance to complain about some unused variable C<mumble>
declared at line 10 in F<foo.c>, one could do:

  msg 'unused', 'foo.c:10', "unused variable `mumble'";

If channel C<unused> is not silent (and if this message is not a duplicate),
the following would be output:

  foo.c:10: unused variable `mumble'

If C<$message> contains new line caracters, C<$location> is prepended
to each line.  For instance

  msg 'error', 'somewhere', "1st line\n2nd line";

becomes

  somewhere: 1st line
  somewhere: 2nd line

If C<$location> is an empty string, it is replaced by the name of the
program.  Actually, if you don't use C<%options>, you can even
elide the empty C<$location>.  Thus

  msg 'fatal', '', 'fatal error';
  msg 'fatal', 'fatal error';

both print

  progname: fatal error

=cut


use vars qw (@backlog %buffering);

# See buffer_messages() and flush_messages() below.
%buffering = ();	# The map of channel types to buffer.
@backlog = ();		# The buffer of messages.

sub msg ($$;$%)
{
  my ($channel, $location, $message, %options) = @_;

  if (! defined $message)
    {
      $message = $location;
      $location = '';
    }

  confess "unknown channel $channel" unless exists $channels{$channel};

  my %opts = %{$channels{$channel}};
  _merge_options (%opts, %options);

  if (exists $buffering{$opts{'type'}})
    {
      push @backlog, [@_];
      return;
    }

  # Print the message if needed.
  if (_print_message ($location, $message, %opts))
    {
      # Adjust exit status.
      if ($opts{'type'} eq 'error'
	  || $opts{'type'} eq 'fatal'
	  || ($opts{'type'} eq 'warning' && $warnings_are_errors))
	{
	  my $es = $opts{'exit_code'};
	  $exit_code = $es if $es > $exit_code;
	}

      # Die on fatal messages.
      confess if $opts{'backtrace'};
      exit $exit_code if $opts{'type'} eq 'fatal';
    }
}


=item C<setup_channel ($channel, %options)>

Override the options of C<$channel> with those specified by C<%options>.

=cut

sub setup_channel ($%)
{
  my ($name, %opts) = @_;
  confess "channel $name doesn't exist" unless exists $channels{$name};
  _merge_options %{$channels{$name}}, %opts;
}

=item C<setup_channel_type ($type, %options)>

Override the options of any channel of type C<$type>
with those specified by C<%options>.

=cut

sub setup_channel_type ($%)
{
  my ($type, %opts) = @_;
  foreach my $channel (keys %channels)
    {
      setup_channel $channel, %opts
	if $channels{$channel}{'type'} eq $type;
    }
}

=item C<dup_channel_setup ()>, C<drop_channel_setup ()>

Sometimes it is necessary to make temporary modifications to channels.
For instance one may want to disable a warning while processing a
particular file, and then restore the initial setup.  These two
functions make it easy: C<dup_channel_setup ()> saves a copy of the
current configuration for later restoration by
C<drop_channel_setup ()>.

You can think of this as a stack of configurations whose first entry
is the active one.  C<dup_channel_setup ()> duplicates the first
entry, while C<drop_channel_setup ()> just deletes it.

=cut

use vars qw (@_saved_channels);
@_saved_channels = ();

sub dup_channel_setup ()
{
  my %channels_copy;
  foreach my $k1 (keys %channels)
    {
      $channels_copy{$k1} = {%{$channels{$k1}}};
    }
  push @_saved_channels, \%channels_copy;
}

sub drop_channel_setup ()
{
  my $saved = pop @_saved_channels;
  %channels = %$saved;
}

=item C<buffer_messages (@types)>, C<flush_messages ()>

By default, when C<msg> is called, messages are processed immediately.

Sometimes it is necessary to delay the output of messages.
For instance you might want to make diagnostics before
channels have been completly configured.

After C<buffer_messages(@types)> has been called, messages sent with
C<msg> to a channel whose type is listed in C<@types> will be stored in a
list for later processing.

This backlog of messages is processed when C<flush_messages> is
called, with the current channel options (not the options in effect,
at the time of C<msg>).  So for instance if some channel was silenced
in the meantime, messages to this channels will not be print.

C<flush_messages> cancels the effect of C<buffer_messages>.  Following
calls to C<msg> are processed immediately as usual.

=cut

sub buffer_messages (@)
{
  foreach my $type (@_)
    {
      $buffering{$type} = 1;
    }
}

sub flush_messages ()
{
  %buffering = ();
  foreach my $args (@backlog)
    {
      &msg (@$args);
    }
  @backlog = ();
}

=back

=head1 HISTORY

Written by Alexandre Duret-Lutz E<lt>F<adl@gnu.org>E<gt>.

=cut

1;

### Setup "GNU" style for perl-mode and cperl-mode.
## Local Variables:
## perl-indent-level: 2
## perl-continued-statement-offset: 2
## perl-continued-brace-offset: 0
## perl-brace-offset: 0
## perl-brace-imaginary-offset: 0
## perl-label-offset: -2
## cperl-indent-level: 2
## cperl-brace-offset: 0
## cperl-continued-brace-offset: 0
## cperl-label-offset: -2
## cperl-extra-newline-before-brace: t
## cperl-merge-trailing-else: nil
## cperl-continued-statement-offset: 2
## End:
