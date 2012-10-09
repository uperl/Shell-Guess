package Shell::Guess;

use strict;
use warnings;
use File::Spec;

# ABSTRACT: make an educated guess about the shell in use
# VERSION

=head1 SYNOPSIS

guessing and using shell which called the Perl script:

 use Shell::Guess;
 my $shell = Shell::Guess->running_shell;
 if($shell->is_c)
 {
   print "setenv FOO bar\n";
 }
 elsif($shell->is_bourne)
 {
   print "export FOO=bar\n";
 }

guessing the current user's login shell:

 use Shell::Guess;
 my $shell = Shell::Guess->login_shell;
 print $shell->name, "\n";

guessing an arbitrary user's login shell:

 use Shell::Guess;
 my $shell = Shell::Guess->login_shell('bob');
 print $shell->name, "\n";

=head1 DESCRIPTION

TODO

=head1 CLASS METHODS

=head2 Shell::Guess->running_shell

TODO

=cut

sub running_shell
{
  ## TODO use Win32::Process::List
  ## maybe a nice idea, but without a getppid replacement
  ## won't be of much use.
  #if($^O eq 'Win32' || $^O eq 'cygwin')
  #{
  #  my $pl_shell = eval {
  #    require Win32::Process::List;
  #    Win32::Process::List->new->{processes}->{getppid()};
  #  };
  #}

  if($^O eq 'MSWin32')
  {
    # TODO detect powershell
    if($ENV{ComSpec} =~ /cmd\.exe$/)
    { return __PACKAGE__->cmd_shell }
    else
    { return __PACKAGE__->command_shell }
  }

  if($^O eq 'VMS')
  {
    return __PACKAGE__->dcl_shell;
  }

  my $shell = eval {
    open my $fh, '<', File::Spec->catfile('', 'proc', getppid, 'cmdline');
    my $command_line = <$fh>;
    close $fh;
    $command_line =~ s/\0$//;
    _unixy_shells($command_line);
  };
  $shell || __PACKAGE__->login_shell;
}

=head2 Shell::Guess->login_shell

TODO

=cut

sub login_shell
{
  shift; # class ignored
  my $shell;

  if($^O eq 'MSWin32')
  {
    if(Win32::IsWin95())
    { return __PACKAGE__->command_shell }
    else
    { return __PACKAGE__->cmd_shell }
  }

  if($^O eq 'VMS')
  {
    return __PACKAGE__->dcl_shell;
  }

  eval {
    my $pw_shell = (getpwnam(shift||$ENV{USER}||$ENV{USERNAME}||$ENV{LOGNAME}))[-1];
    $shell = _unixy_shells($pw_shell);
    $shell = _unixy_shells(readlink $pw_shell) if !defined($shell) && -l $pw_shell;
  };

  $shell = __PACKAGE__->bourne_shell unless defined $shell;

  return $shell;
}

=head2 Shell::Guess-E<gt>bash_shell

TODO

=head2 Shell::Guess-E<gt>c_shell

TODO

=head2 Shell::Guess-E<gt>bourne_shell

TODO

=head2 Shell::Guess-E<gt>c_shell

TODO

=head2 Shell::Guess-E<gt>cmd_shell

TODO

=head2 Shell::Guess-E<gt>command_shell

TODO

=head2 Shell::Guess-E<gt>dcl_shell

TODO

=head2 Shell::Guess-E<gt>korn_shell

TODO

=head2 Shell::Guess-E<gt>tc_shell

TODO

=cut

sub cmd_shell     { bless { cmd => 1, win32 => 1,              name => 'cmd'     }, __PACKAGE__ }
sub command_shell { bless { command => 1, win32 => 1,          name => 'command' }, __PACKAGE__ }
sub dcl_shell     { bless { dcl => 1, vms => 1,                name => 'dcl'     }, __PACKAGE__ }
sub bash_shell    { bless { bash => 1, bourne => 1, unix => 1, name => 'bash'    }, __PACKAGE__ }
sub bourne_shell  { bless { bourne => 1, unix => 1,            name => 'bourne'  }, __PACKAGE__ }
sub korn_shell    { bless { korn => 1, bourne => 1, unix => 1, name => 'korn'    }, __PACKAGE__ }
sub c_shell       { bless { c => 1, unix => 1,                 name => 'c'       }, __PACKAGE__ }
sub tc_shell      { bless { c => 1, tc => 1, unix => 1,        name => 'tc'      }, __PACKAGE__ }

=head1 INSTANCE METHODS

The normal way to call these is by calling them on the result of either
I<running_shell> or I<login_shell>, but they can also be called as class
methods, in which case the currently running shell will be used, so

 Shell::Guess->is_bourne

is the same as

 Shell::Guess->running_shell->is_bourne

=head2 $shell-E<gt>is_bash

TODO

=head2 $shell-E<gt>is_bourne

TODO

=head2 $shell-E<gt>is_c

TODO

=head2 $shell-E<gt>is_cmd

TODO

=head2 $shell-E<gt>is_command

TODO

=head2 $shell-E<gt>is_dcl

TODO

=head2 $shell-E<gt>is_korn

TODO

=head2 $shell-E<gt>is_tc

TODO

=head2 $shell-E<gt>is_unix

TODO

=head2 $shell-E<gt>is_vms

TODO

=head2 $shell-E<gt>is_win32

TODO

=cut

foreach my $type (qw( cmd command dcl bash korn c win32 unix vms bourne tc ))
{
  eval qq{
    sub is_$type
    {
      my \$self = ref \$_[0] ? shift : __PACKAGE__->running_shell;
      \$self->{$type} || 0;
    }
  };
  die $@ if $@;
}

=head2 $shell-E<gt>name

TODO

=cut

sub name
{
  my $self = ref $_[0] ? shift : __PACKAGE__->running_shell;
  $self->{name};
}

sub _unixy_shells
{
  my $shell = shift;
  if($shell =~ /tcsh$/)
  { return __PACKAGE__->tc_shell     }
  elsif($shell =~ /csh$/)
  { return __PACKAGE__->c_shell      }
  elsif($shell =~ /ksh$/)
  { return __PACKAGE__->korn_shell   }
  elsif($shell =~ /bash$/)
  { return __PACKAGE__->bash_shell   }
  elsif($shell =~ /sh$/)
  { return __PACKAGE__->bourne_shell }
  else
  { return; }
}

1;

=head1 CAVEATS

Shell::Guess shouldn't ever die or crash, instead it will attempt to make a guess or use a fallback 
about either the login or running shell even on unsupported operating systems.  The fallback is the 
most common shell on the particular platform that you are using, so on UNIXy platforms the fallback 
is bourne, and on VMS the fallback is VMS.

These are the operating systems that have been tested in development and are most likely to guess
reliably.

=over 4

=item * Linux

=item * Cygwin

=item * Windows (Strawberry Perl)

=item * OpenVMS

=back

Patcher are welcome to make other platforms work more reliably.

=cut
