package App::CPAN::Changes;

# DATE
# VERSION

#use 5.010001;
use strict;
use warnings;

use Fcntl qw(:DEFAULT);
use POSIX qw(strftime);

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'CLI for CPAN::Changes',
};

sub _parse {
    my ($file) = @_;

    if (!$file) {
	for (qw/Changes CHANGES ChangeLog CHANGELOG/) {
	    do { $file = $_; last } if -f $_;
	}
    }
    die "Please specify file ".
        "(or run in directory where Changes file exists)"
        unless $file;

    require CPAN::Changes;
    ($file, CPAN::Changes->load($file));
}

my %common_args = (
    file => {
        schema => 'str*', # XXX filename
        summary => 'If not specified, will look for file called '.
            'Changes/CHANGELOG/etc in current directory',
        cmdline_aliases => {f=>{}},
        tags => ['common'],
    },
);

$SPEC{check} = {
    v => 1.1,
    summary => 'Check for parsing errors in Changes file',
    args => {
        %common_args,
    },
};
sub check {
    my %args = @_;

    my ($file, $ch) = _parse($args{file});
    my @rels = $ch->releases;
    return [400, "No releases found"] unless @rels;

    [200, "OK"];
}

$SPEC{dump} = {
    v => 1.1,
    summary => 'Dump Changes as JSON structure',
    args => {
        %common_args,
    },
};
sub dump {
    my %args = @_;

    my ($file, $ch) = _parse($args{file});

    [200, "OK", $ch];
}

sub _serialize {
    my ($ch, $reverse) = @_;

    $ch->serialize(reverse => $reverse);
}

sub _write {
    my ($file, $ch, $reverse) = @_;

    my $tempfile = sprintf("%s.%05d.tmp", $file, rand()*65536);
    sysopen my($fh), $tempfile, O_WRONLY|O_CREAT|O_EXCL
        or die "Can't open temp file '$tempfile': $!";
    print $fh _serialize($ch, $reverse);
    rename $file, "$file.bak"
        or die "Can't move '$file' to '$file.bak': $!";
    rename $tempfile, $file
        or die "Can't move '$tempfile' to '$file': $!";
}

$SPEC{preamble} = {
    v => 1.1,
    summary => 'Get/set preamble',
    tags => ['write'],
    args => {
        %common_args,
        preamble => {
            summary => 'Set new preamble',
            schema => 'str*',
            pos => 0,
        },
    },
};
sub preamble {
    my %args = @_;

    my ($file, $ch) = _parse($args{file});

    if (defined $args{preamble}) {
        $ch->preamble($args{preamble});
        _write($file, $ch);
        [200, "OK"];
    } else {
        [200, "OK", $ch->preamble];
    }
}

$SPEC{release} = {
    v => 1.1,
    summary => 'Return information (JSON object dump) of a specific release',
    args => {
        %common_args,
        version => {
            schema => 'str*',
            req => 1,
            pos => 0,
        },
    },
};
sub release {
    my %args = @_;

    my ($file, $ch) = _parse($args{file});

    my $rel = $ch->release($args{version});

    [200, "OK", $rel];
}

$SPEC{add_release} = {
    v => 1.1,
    summary => 'Add a new release',
    tags => ['write'],
    args => {
        %common_args,
        version => {
            schema => 'str*',
            req => 1,
            pos => 0,
            cmdline_aliases => {V=>{}},
        },
        date => {
            schema => 'date*',
            req => 1,
            pos => 1,
        },
        changes => {
            'x.name.is_plural' => 1,
            schema => ['array*', of=>'str*', min_len=>1],
            req => 1,
            pos => 2,
            greedy => 1,
        },
        note => {
            schema => 'str*',
        },
    },
    features => {
        dry_run => 1,
    },
};
sub add_release {
    my %args = @_;

    my ($file, $ch) = _parse($args{file});

    # format to YYYY-MM-DD
    my $date = strftime("%Y-%m-%d",
                        localtime $args{date});

    my $rel = CPAN::Changes::Release->new(
        version => $args{version},
        date    => $date,
    );
    $rel->note($args{note}) if $args{note};
    my @c;
    for my $c (@{ $args{changes} }) {
        if ($c =~ /\A\[(.+)\]\z/) {
            push @c, {group => $1};
        } else {
            push @c, $c;
        }
    }
    $rel->add_changes(@c);

    $ch->add_release($rel);

    if ($args{-dry_run}) {
        return [304, "Not modified", _serialize($ch)];
    } else {
        _write($file, $ch);
        return [200, "OK"];
    }
}

1;
# ABSTRACT:

=head1 SYNOPSIS

See included script L<cpan-changes>.


=head1 SEE ALSO

L<CPAN::Changes>

L<parse-cpan-changes> (from L<App::ParseCPANChanges>)

=cut
