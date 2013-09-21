package HTTP::Body::Builder::MultiPart;
use strict;
use warnings;
use utf8;
use 5.010_001;

use File::Basename ();

my $CRLF = "\015\012";

sub new {
    my $class = shift;
    my %args = @_==1 ? %{$_[0]} : @_;
    bless {
        boundary => 'xYzZY',
        buffer_size => 2048,
        %args
    }, $class;
}

sub add_content {
    my ($self, $name, $value) = @_;
    push @{$self->{content}}, [$name, $value];
}

sub add_file {
    my ($self, $name, $filename) = @_;
    push @{$self->{file}}, [$name, $filename];
}

sub content_type {
    my $self = shift;
    return 'multipart/form-data';
}

sub _gen {
    my ($self, $code) = @_;

    for my $row (@{$self->{content}}) {
        $code->(join('', "--$self->{boundary}$CRLF",
            qq{Content-Disposition: form-data; name="$row->[0]"$CRLF},
            "$CRLF",
            $row->[1] . $CRLF
        ));
    }
    for my $row (@{$self->{file}}) {
        my $filename = File::Basename::basename($row->[1]);
        $code->(join('', "--$self->{boundary}$CRLF",
            qq{Content-Disposition: form-data; name="$row->[0]"; filename="$filename"$CRLF},
            "Content-Type: text/plain$CRLF",
            "$CRLF",
        ));
        open my $fh, '<:raw', $row->[1]
            or do {
            $self->{errstr} = "Cannot open '$row->[1]' for reading: $!";
            return;
        };
        my $buf;
        while (1) {
            my $r = read $fh, $buf, $self->{buffer_size};
            if (not defined $r) {
                $self->{errstr} = "Cannot open '$row->[1]' for reading: $!";
                return;
            } elsif ($r == 0) { # eof
                last;
            } else {
                $code->($buf);
            }
        }
        $code->($CRLF);
    }
    $code->("--$self->{boundary}--$CRLF");
    return 1;
}

sub as_string {
    my ($self) = @_;
    my $buf = '';
    $self->_gen(sub { $buf .= $_[0] })
        or return;
    $buf;
}

sub errstr { shift->{errstr} }

sub write_file {
    my ($self, $filename) = @_;

    open my $fh, '>:raw', $filename
        or do {
        $self->{errstr} = "Cannot open '$filename' for writing: $!";
        return;
    };
    $self->_gen(sub { print {$fh} $_[0] })
        or return;
    close $fh;
}

1;
__END__

=head1 NAME

HTTP::Body::Builder::MultiPart - multipart/form-data

=head1 SYNOPSIS

    use HTTP::Body::Builder::MultiPart;

    my $builder = HTTP::Body::Builder::MultiPart->new();
    $builder->add('x' => 'y');
    $builder->as_string;
    # => x=y

=head1 METHODS

=over 4

=item my $builder = HTTP::Body::Builder::MultiPart->new()

Create new instance of HTTP::Body::Builder::MultiPart.

=item $builder->add_content($key => $value);

Add new parameter in raw string.

=item $builder->add_file($key => $real_file_name);

Add C<$real_file_name> as C<$key>.

=item $builder->as_string();

Generate body as string.

=item $builder->write_file($filename);

Write the content to C<$filename>.

=back
