package Shell::Guess;

use strict;
use warnings;
use File::Spec;

# ABSTRACT: make an educated guess about the shell in use
# VERSION

=head1 SYNOPSIS

guessing shell which called the Perl script:

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

Shell::Guess makes a reasonably aggressive attempt to determine the shell
being employed by the user, either the shell that executed the perl script
directly (the "running" shell), or the users' default login shell (the 
"login" shell).  It does this by a variety of means available to it, depending 
on the platform that it is running on, for example on Linux it will use the
/proc filesystem to determine the running shell and getpwent to determine the
login shell.  On Windows it will use the ComSpec environment variable to 
differentiate between C<command.com> and C<cmd.exe>.  If Sell::Guess does
not know enough about your platform to make an educated guess, it will use
a platform fallback (bourne shell on UNIX, command.com on Windows 95, cmd.exe on
Windows NT and dcl on OpenVMS, for example).

=head1 CLASS METHODS

These class methods return an instance of Shell::Guess, which can then be 
interrogated by the instance methods in the next section below.

=head2 Shell::Guess->running_shell

Returns an instance of Shell::Guess based on the shell which directly
started the current Perl script.  If the running shell cannot be determined,
it will return the login shell.

=cut

sub _win32_getppid
{
  require Win32::Process::Info;
  Win32::Process::Info->import;
  my $my_pid = Win32::GetCurrentProcessId();
  my($parent_pid) = map { $_->{ParentProcessId} } grep { $_->{ProcessId} == $my_pid } Win32::Process::Info->new->GetProcInfo;
  return $parent_pid;
}

sub running_shell
{
  if($^O eq 'MSWin32')
  {
    my $shell_name = eval {
      require Win32::Process::List;
      my $parent_pid = _win32_getppid();
      Win32::Process::List->new->{processes}->[0]->{$parent_pid}
    };
    if(defined $shell_name)
    {
      print "shell_name = $shell_name\n";
      if($shell_name =~ /cmd\.exe$/)
      { return __PACKAGE__->cmd_shell }
      elsif($shell_name =~ /powershell\.exe$/)
      { return __PACKAGE__->power_shell }
      elsif($shell_name =~ /command\.com$/)
      { return __PACKAGE__->command_shell }
    }
  }

  if($^O eq 'MSWin32')
  {
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
    open(my $fh, '<', File::Spec->catfile('', 'proc', getppid, 'cmdline')) || die;
    my $command_line = <$fh>;
    close $fh;
    $command_line =~ s/\0$//;
    _unixy_shells($command_line);
  }
  
  || eval {
    require Unix::Process;
    my($command) = map { s/\s+.*$//; $_ } Unix::Process->command(getppid);
    _unixy_shells($command);
  };
  
  $shell || __PACKAGE__->login_shell;
}

=head2 Shell::Guess->login_shell( [ $username ] )

Returns an instance of Shell::Guess for the given user.  If no username is specified then
the current user will be used.  If no shell can be guessed then a reasonable fallback
will be chosen based on your platform.

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

Returns an instance of Shell::Guess for bash.

The following instance methods will return:

=over 4

=item * $shell-E<gt>name = bash

=item * $shell-E<gt>is_bash = 1

=item * $shell-E<gt>is_bourne = 1

=item * $shell-E<gt>is_unix = 1

=back

All other instance methods will return false

=cut

sub bash_shell    { bless { bash => 1, bourne => 1, unix => 1, name => 'bash'    }, __PACKAGE__ }

=head2 Shell::Guess-E<gt>bourne_shell

Returns an instance of Shell::Guess for the bourne shell.

The following instance methods will return:

=over 4

=item * $shell-E<gt>name = bourne

=item * $shell-E<gt>is_bourne = 1

=item * $shell-E<gt>is_unix = 1

=back

All other instance methods will return false

=cut

sub bourne_shell  { bless { bourne => 1, unix => 1,            name => 'bourne'  }, __PACKAGE__ }

=head2 Shell::Guess-E<gt>c_shell

Returns an instance of Shell::Guess for c shell.

The following instance methods will return:

=over 4

=item * $shell-E<gt>name = c

=item * $shell-E<gt>is_c = 1

=item * $shell-E<gt>is_unix = 1

=back

All other instance methods will return false

=cut

sub c_shell       { bless { c => 1, unix => 1,                 name => 'c'       }, __PACKAGE__ }

=head2 Shell::Guess-E<gt>cmd_shell

Returns an instance of Shell::Guess for the Windows NT cmd shell (cmd.exe).

The following instance methods will return:

=over 4

=item * $shell-E<gt>name = cmd

=item * $shell-E<gt>is_cmd = 1

=item * $shell-E<gt>is_win32 = 1

=back

All other instance methods will return false

=cut

sub cmd_shell     { bless { cmd => 1, win32 => 1,              name => 'cmd'     }, __PACKAGE__ }

=head2 Shell::Guess-E<gt>command_shell

Returns an instance of Shell::Guess for the Windows 95 command shell (command.com).

The following instance methods will return:

=over 4

=item * $shell-E<gt>name = command

=item * $shell-E<gt>is_command = 1

=item * $shell-E<gt>is_win32 = 1

=back

All other instance methods will return false

=cut

sub command_shell { bless { command => 1, win32 => 1,          name => 'command' }, __PACKAGE__ }

=head2 Shell::Guess-E<gt>dcl_shell

Returns an instance of Shell::Guess for the OpenVMS dcl shell.

The following instance methods will return:

=over 4

=item * $shell-E<gt>name = dcl

=item * $shell-E<gt>is_dcl = 1

=item * $shell-E<gt>is_vms = 1

=back

All other instance methods will return false

=cut

sub dcl_shell     { bless { dcl => 1, vms => 1,                name => 'dcl'     }, __PACKAGE__ }

=head2 Shell::Guess-E<gt>korn_shell

Returns an instance of Shell::Guess for the korn shell.

The following instance methods will return:

=over 4

=item * $shell-E<gt>name = korn

=item * $shell-E<gt>is_korn = 1

=item * $shell-E<gt>is_bourne = 1

=item * $shell-E<gt>is_unix = 1

=back

All other instance methods will return false

=cut

sub korn_shell    { bless { korn => 1, bourne => 1, unix => 1, name => 'korn'    }, __PACKAGE__ }

=head2 Shell::Guess-E<gt>power_shell

Returns an instance of Shell::Guess for Windows PowerShell.

The following instance methods will return:

=over 4

=item * $shell-E<gt>name = power

=item * $shell-E<gt>is_power = 1

=item * $shell-E<gt>is_win32 = 1

=back

All other instance methods will return false

=cut

sub power_shell   { bless { power => 1, win32 => 1,            name => 'power'   }, __PACKAGE__ }

=head2 Shell::Guess-E<gt>tc_shell

Returns an instance of Shell::Guess for tcsh.

The following instance methods will return:

=over 4

=item * $shell-E<gt>name = tc

=item * $shell-E<gt>is_tc = 1

=item * $shell-E<gt>is_c = 1

=item * $shell-E<gt>is_unix = 1

=back

All other instance methods will return false

=cut

sub tc_shell      { bless { c => 1, tc => 1, unix => 1,        name => 'tc'      }, __PACKAGE__ }

=head1 INSTANCE METHODS

The normal way to call these is by calling them on the result of either
I<running_shell> or I<login_shell>, but they can also be called as class
methods, in which case the currently running shell will be used, so

 Shell::Guess->is_bourne

is the same as

 Shell::Guess->running_shell->is_bourne

=head2 $shell-E<gt>is_bash

Returns true if the shell is bash.

=head2 $shell-E<gt>is_bourne

Returns true if the shell is the bourne shell, or a shell which supports bourne syntax (e.g. bash or korn).

=head2 $shell-E<gt>is_c

Returns true if the shell is csh, or a shell which supports csh syntax (e.g. tcsh).

=head2 $shell-E<gt>is_cmd

Returns true if the shell is the Windows command.com shell.

=head2 $shell-E<gt>is_command

Returns true if the shell is the Windows cmd.com shell.

=head2 $shell-E<gt>is_dcl

Returns true if the shell is the OpenVMS dcl shell.

=head2 $shell-E<gt>is_korn

Returns true if the shell is the korn shell.

=head2 $shell-E<gt>is_power

Returns true if the shell is Windows PowerShell.

=head2 $shell-E<gt>is_tc

Returns true if the shell is tcsh.

=head2 $shell-E<gt>is_unix

Returns true if the shell is traditionally a UNIX shell (e.g. bourne, bash, korn)

=head2 $shell-E<gt>is_vms

Returns true if the shell is traditionally an OpenVMS shell (e.g. dcl)

=head2 $shell-E<gt>is_win32

Returns true if the shell is traditionally a Windows shell (command.com, cmd.exe)

=cut

foreach my $type (qw( cmd command dcl bash korn c win32 unix vms bourne tc power ))
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

Returns the name of the shell.

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

# FIXME: getpwent doesn't work on OS X
# TODO: require Unix::Process if there is no /proc/$$

1;

=head1 CAVEATS

Shell::Guess shouldn't ever die or crash, instead it will attempt to make a guess or use a fallback 
about either the login or running shell even on unsupported operating systems.  The fallback is the 
most common shell on the particular platform that you are using, so on UNIXy platforms the fallback 
is bourne, and on OpenVMS the fallback is dcl.

These are the operating systems that have been tested in development and are most likely to guess
reliably.

=over 4

=item * Linux

=item * Cygwin

=item * FreeBSD

=item * Mac OS X

=item * Windows (Strawberry Perl)

Can detect PowerShell, but only if optional prereqs L<Win32::Process::Info> and L<Win32::Process::List>
are installed.  Otherwise will use ComSpec environment to guess the running shell.  On Windows NT
style operating systems the login shell will be cmd and on Windows 95 style operating systems the
login shell will be command.

=item * OpenVMS

Always detected as dcl (a more nuanced view of OpenVMS is probably possible, patches welcome).

=back

UNIXy platforms without a /proc filesystem will use L<Unix::Process> if installed, which will execute 
ps to determine the running shell.

Patches are welcome to make other platforms work more reliably.

=cut
