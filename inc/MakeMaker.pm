package inc::MakeMaker;

use Moose;
use namespace::autoclean;
use v5.10;

with 'Dist::Zilla::Role::InstallTool';

sub setup_installer
{
  my($self) = @_;
  
  my($makefile) = grep { $_->name eq 'Makefile.PL' } @{ $self->zilla->files };
  
  my $content = $makefile->content;
  
  state $checks;
  unless($checks)
  {
    $checks = do { local $/; <DATA> };
  }
  
  if($content =~ s{(WriteMakefile\()}{$checks$1}m)
  {
    $makefile->content($content);
    $self->zilla->log("Modified Makefile.PL with extra checks");
  }
  else
  {
    $self->zilla->log_fatal("unable to update Makefile.PL");
  }
}

1;

__DATA__

if($^O ne 'dos' && $^O ne 'VMS' && $^O ne 'MSWin32' && eval { getppid; 1 })
{
  unless(-e File::Spec->catfile('', 'proc', getppid, 'cmdline'))
  {
    $WriteMakefileArgs{PREREQ_PM}->{'Unix::Process'} = 0;
  }
}

if($^O eq 'MSWin32')
{
  $WriteMakefileArgs{PREREQ_PM}->{'Win32::Process::Info'} = 0;
  $WriteMakefileArgs{PREREQ_PM}->{'Win32::Process::List'} = 0;
}


