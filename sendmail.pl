#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use Encode;
use MIME::Base64;
use Getopt::Long;
use feature qw(say);
use Digest::MD5 qw(md5_hex);

binmode STDOUT, ":utf8";
binmode STDIN,  ":utf8";

# 引数処理
my $help;
my %mail;

GetOptions(
    'subject=s' => \$mail{'subject'},
    'from=s'    => \$mail{'from'},
    'help'      => \$help
);

# help
if ($help or @ARGV+0 == 0){
    say "usage: $0 [ --from Fromアドレス] [--subject 件名] 宛先1 [宛先2]...";
    exit;
}
# body
{
    local $/ = undef;
    $mail{'body'} = <STDIN>;
}

# sendmail
for (@ARGV){
    sendmail(
        to => $_,
        subject => $mail{'subject'},
        from    => $mail{'from'},
        body    => $mail{'body'}
    );
}

sub sendmail {
    my %params = @_;
    my $sendmail_cmd = "/usr/sbin/sendmail ";
    if (defined($params{'from'})){
        $sendmail_cmd .= "-f $params{'from'} ";
    }
    $sendmail_cmd .= $params{'to'};
    open (my $sendmailfh, "|-:encoding(UTF-8)", $sendmail_cmd) or die $!;
    {
        my $header = sub {
            my %params = @_;
            my $date;
            {
                $ENV{'TZ'} = "JST-9";
                my ($sec,$min,$hour,$mday,$mon,$year,$wday) = localtime(time);
                my @week = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
                my @month = ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');
                $date = sprintf("%s, %d %s %04d %02d:%02d:%02d +0900 (JST)", $week[$wday],$mday,$month[$mon],$year+1900,$hour,$min,$sec);
            } 
            my $mail_subject = `echo "$params{'subject'}" | nkf -W -M -w`;
            chomp $mail_subject;
            my $message_id = md5_hex(time().$mail_subject.$params{'to'});
            my $to = $params{'to'};
            my $from = $params{'from'};
            my $head = 
              "From: $from\n"
            . "To: $to\n"
            . "Content-Type: text/plain; charset=UTF-8\n"
            . "Message-Id: <$message_id>\n"
            . "Date: $date\n"
            . "Subject: $mail_subject\n"
            . "Content-Transfer-Encoding: Base64\n"
            ;
            return $head;

        };
        print $sendmailfh $header->(
            to      => $params{'to'},
            subject => defined($params{'subject'}) ? $params{'subject'} : "",
            from    => defined($params{'from'})    ? $params{'from'}    : $params{'to'}
        );
        print $sendmailfh encode_base64(encode('UTF-8',$params{'body'}));
    }
    close $sendmailfh;
}
