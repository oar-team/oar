# Check if job types are valid
my @types = (
    qr/^container(?:=\w+)?$/,                 qr/^deploy(?:=standby)?$/,
    qr/^desktop_computing$/,                   qr/^besteffort$/,
    qr/^cosystem(?:=standby)?$/,                qr/^idempotent$/,
    qr/^placeholder=\w+$/,                    qr/^allowed=\w+$/,
    qr/^inner=\w+$/,                          qr/^timesharing=(?:(?:\*|user),(?:\*|name)|(?:\*|name),(?:\*|user))$/,
    qr/^token\:\w+\=\d+$/,                 qr/^noop(?:=standby)?$/,
    qr/^(?:postpone|deadline|expire)=\d\d\d\d-\d\d-\d\d(?:\s+\d\d:\d\d(?::\d\d)?)?$/,
    qr/^(?:evening|night|week-end)=\d\d\d\d-\d\d-\d\d$/,
);
foreach my $t ( @{$type_list} ) {
    my $match = 0;
    foreach my $r (@types) {
        if ($t =~ $r) {
            $match = 1;
        }
    }
    unless ( $match ) {
        die( "[ADMISSION RULE] Error: unknown job type: $t\n");
    }
}
