class YAML::Dumper;

has $.out = [];
has $.seen is rw = {};
has $.anchors = {};
has $.level is rw = 0;
has $.id is rw = 1;
has $.info = [];

method dump($object) {
    $.prewalk($object);
    $.seen = ();
    $.dump_document($object);
    return $.out.join('');
}

method dump_document($node) {
    push $.out, '---';
    $.dump_node($node);
    push $.out, "\n", "...", "\n";
}

method dump_collection($node, $kind, $function) {
    $.level++;
    push $.info, {
        kind => $kind,
    };
    given ++$.seen{$node.WHICH} {
        when 1 {
            $function.();
        }
        default {
            $.dump_alias($node);
        }
    }
    pop $.info;
    $.level--;
}

method check_anchor($node) {
    if $.anchors.exists($node.WHICH) {
        push $.out, ' ', '&' ~ $.anchors{$node.WHICH};
        return 0;
    }
    else {
        return 1;
    }
}

method indent($first) {
    if ($first && $.level > 1 && $.info[*-2]<kind> eq 'seq') {
        push $.out, ' ';
    }
    else {
        push $.out, "\n";
        push $.out, ' ' x (($.level - 1) * 2);
    }
}

multi method dump_node(Hash $node) {
    $.dump_collection($node, 'map', sub {
        my $first = $.check_anchor($node);
        for $node.keys.sort -> $key {
            $.indent($first);
            push $.out, $key.Str;
            push $.out, ':';
            $.dump_node($node{$key});
            $first = 0;
        }
    });
}

multi method dump_node(Array $node) {
    $.dump_collection($node, 'seq', sub {
        my $first = $.check_anchor($node);
        for @($node) -> $elem {
            $.indent($first);
            push $.out, '-';
            $.dump_node($elem);
            $first = 0;
        }
    });
}

multi method dump_node(Str $node) {
    push $.out, ' ', $node.Str;
}

multi method dump_node(Int $node) {
    push $.out, ' ', $node.Str;
}

multi method dump_node($node) {
    die "Can't dump a node of type " ~ $node.WHAT;
}

multi method dump_alias($node) {
    push $.out, ' ', '*' ~ $.anchors{$node.WHICH};
}

# Prewalk methods
method check_reference($node, $function) {
    my $id = $node.WHICH;
    given ++$.seen{$id} {
        when 1 {
            $function.();
        }
        when 2 {
            $.anchors{$id} = $.id++;
        }
    }
}

multi method prewalk(Hash $node) {
    $.check_reference($node, sub {
        for $node.values -> $value {
            $.prewalk($value);
        }
    });
}

multi method prewalk(Array $node) {
    $.check_reference($node, sub {
        for @($node) -> $value {
            $.prewalk($value);
        }
    });
}

multi method prewalk($node) {
    return if $node.WHAT eq any('Str()', 'Int()');
    die "Can't prewalk a node of type " ~ $node.WHAT;
}

