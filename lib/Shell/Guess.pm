package Shell::Guess;

use strict;
use warnings;
use File::Spec;

# ABSTRACT: make an educated guess about the shell in use
# VERSION

sub running_shell
{
  if($^O eq 'MSWin32')
  {
    if($ENV{ComSpec} =~ /cmd\.exe$/)
    { return __PACKAGE__->cmd_shell }
    else
    { return __PACKAGE__->command_shell }
  }
  
  if($^O eq 'VMS')
  {
    die 'FIXME';
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

sub login_shell
{
  shift; # class ignored
  my $shell;
  
  if($^O eq 'MSWin32')
  {
    if(Win32::IsWin95)
    { return __PACKAGE__->command_shell }
    else
    { return __PACKAGE__->cmd_shell }
  }
  
  if($^O eq 'VMS')
  {
    die 'FIXME';
  }
  
  eval {
    my $pw_shell = (getpwnam(shift||$ENV{USER}||$ENV{USERNAME}||$ENV{LOGNAME}))[-1];
    $shell = _unixy_shells($pw_shell);
    $shell = _unixy_shells(readlink $pw_shell) if !defined($shell) && -l $pw_shell;
  };
  
  $shell = __PACKAGE__->bourne_shell unless defined $shell;
  
  return $shell;
}

sub cmd_shell     { bless { cmd => 1, win32 => 1,              name => 'cmd'     }, __PACKAGE__ }
sub command_shell { bless { command => 1, win32 => 1,          name => 'command' }, __PACKAGE__ }
sub dcl_shell     { bless { dcl => 1, vms => 1,                name => 'dcl'     }, __PACKAGE__ }
sub bash_shell    { bless { bash => 1, bourne => 1, unix => 1, name => 'bash'    }, __PACKAGE__ }
sub bourne_shell  { bless { bourne => 1, unix => 1,            name => 'bourne'  }, __PACKAGE__ }
sub korn_shell    { bless { korn => 1, bourne => 1, unix => 1, name => 'korn'    }, __PACKAGE__ }
sub c_shell       { bless { c => 1, unix => 1,                 name => 'c'       }, __PACKAGE__ }
sub tc_shell      { bless { c => 1, tc => 1, unix => 1,        name => 'tc'      }, __PACKAGE__ }

foreach my $type (qw( cmd command dcl bash korn c win32 unix vms bourne tc ))
{
  eval qq{ sub is_$type { shift->{$type} || 0 } };
  die $@ if $@;
}

sub name { shift->{name} }

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

=head1 SUPPORTED SYSTEMS

Shell::Guess will attempt to make a guess or use a fallback about either the login or running shell
even on unsupported operating systems.  That being said, these are the operating systems that have
been tested in development and are most likely to work:

=over 4

=item * Linux

=item * Cygwin

=item * Windows (Strawberry Perl)

=cut

=cut