package inc::ShellGuessMakeMaker;

use Moose;

extends 'Dist::Zilla::Plugin::MakeMaker::Awesome';

override _build_WriteMakefile_dump => sub {
  my($self) = @_;
  my %write_makefile_args = $self->WriteMakefile_args;
  
  my $makefile_args_dumper = do {
    local $Data::Dumper::Quotekeys = 1;
    local $Data::Dumper::Indent    = 1;
    local $Data::Dumper::Sortkeys  = 1;
    Data::Dumper->new(
      [ \%write_makefile_args ],
      [ '*WriteMakefileArgs' ],
    );
  };
  
  my $dump = $makefile_args_dumper->Dump;

  $dump .= q{
  
    use File::Spec;
    
    unless(-e File::Spec->catfile('', 'proc', getppid, 'cmdline'))
    {
      $WriteMakefileArgs{PREREQ_PM}->{'Unix::Process'} = 0;
    }
  
  };
  
  return $dump;
};

__PACKAGE__->meta->make_immutable;
