package Data::FromDDL::RecordSet;
use strict;
use warnings;
use List::Util qw(first);
use JSON ();
use YAML::Tiny ();
use Class::Accessor::Lite (
    rw => [qw(table n cols)],
);

use Data::FromDDL::Util qw(need_quote_data_type);

sub new {
    my ($class, $table, $n) = @_;
    return bless {
        table => $table,
        n => $n,
        cols => [],
    }, $class;
}

sub add_cols {
    my ($self, $field, $values) = @_;
    push $self->{cols}, {
        field => $field,
        values => $values,
    };
}

sub get_values {
    my ($self, $field_name) = @_;
    my $col = first { $_->{field}->name eq $field_name } @{$self->cols};
    if ($col) {
        return wantarray ? @{$col->{values}} : $col->{values};
    } else {
        return undef;
    }
}

sub _construct_rows {
    my ($self, $with_quote) = @_;
    my $cols = $self->cols;
    my @rows;
    for my $i (0..($self->n)-1) {
        my $row = [map { 
            my $field = $_->{field};
            my $values = $_->{values};
            if ($with_quote && need_quote_data_type($field->data_type)) {
                "'" . $values->[$i] . "'";
            } else {
                $values->[$i];
            }
        } @$cols];
        push @rows, $row;
    }

    return @rows;
}

sub _construct_data {
    my $self = shift;
    my $cols = $self->cols;
    my @fields = map { $_->{field} } @$cols;
    my @rows = $self->_construct_rows;

    my $data = {
        table => $self->table->name,
        values => [],
    };
    for my $row (@rows) {
        my $record = {};
        for (0..$#fields) {
            $record->{$fields[$_]->name} = $row->[$_];
        }
        push $data->{values}, $record;
    }
    return $data;
}

sub to_sql {
    my ($self, $pretty) = @_;
    my $cols = $self->cols;
    my @fields = map { $_->{field} } @$cols;
    my @rows = $self->_construct_rows(1);

    my $format;
    my $record_sep;
    if ($pretty) {
        $format = <<"EOL";
INSERT INTO
    `%s` (%s)
VALUES
    %s;
EOL
        $record_sep = ",\n    ";
    } else {
        $format = "INSERT INTO `%s` (%s) VALUES %s;";
        $record_sep = ',';
    }
    my $values = join $record_sep, map { "(" . join(',', @$_) . ")"; } @rows;
    my $columns = join ',', map { $_->name } @fields;
    return sprintf $format, $self->table->name, $columns, $values;
}

sub to_json {
    my ($self, $pretty) = @_;
    my $data = $self->_construct_data;
    if ($pretty) {
        return JSON->new->pretty->encode($data);
    } else {
        return JSON->new->encode($data);
    }
}

sub to_yaml {
    my ($self) = @_;
    my $data = $self->_construct_data;
    return YAML::Tiny::Dump($data);
}

1;