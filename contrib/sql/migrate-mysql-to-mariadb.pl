#!/usr/bin/env perl
use strict;
use warnings;

# Prints the SQL statements neccessary to migrate from a database set up with
# schema-mysql.sql to schema-mariadb.sql

#
# Transform sequence tables into MariaDB sequences
#

#    seq_secret
for my $table (qw(
    seq_application_log
    seq_audittrail
    seq_certificate
    seq_certificate_attributes
    seq_crl
    seq_csr
    seq_csr_attributes
    seq_workflow
    seq_workflow_history
)) {
    printf <<'EOF', $table, $table, $table;
SELECT ifnull(max(seq_number),0) FROM %s INTO @seq;
SET @seq := @seq + 1;
DROP TABLE %s;
SET @sql = CONCAT('CREATE SEQUENCE %s START = ', @seq, ' INCREMENT BY 1 MINVALUE 0 NO MAXVALUE CACHE 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

EOF
}

print "DROP TABLE seq_secret;\n\n";
print "ALTER TABLE audittrail CHANGE COLUMN audittrail_key audittrail_key bigint(20) unsigned NOT NULL;\n";

1;
