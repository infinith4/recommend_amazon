#frequency.pl
#!/usr/bin/perl
use strict;
use warnings;
use HTML::TagParser;
use Encode;
use HTML::TreeBuilder;
use URI::Escape;
use LWP::UserAgent;

my $itemurl = $ARGV[0];

my $html = HTML::TagParser->new("$itemurl");

my $user_agent = "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.1; Trident/4.0)";
my $ua = LWP::UserAgent->new(agent => $user_agent);
my $res = $ua->get($itemurl);
my $content = $res->decoded_content;
my $tree = HTML::TreeBuilder->new;
$tree->parse($content);

#「この商品を買った人はこんな商品も買っています」 に表示されている商品のURL
my $buyitems = $tree->look_down('id','purchaseSimsData')->as_text;
my @morebuylist = split(/,/, $buyitems);

my @buylist = ();
foreach (@morebuylist){
    push(@buylist, "http://www.amazon.co.jp/dp/".$_);#「この商品を買った人はこんな商品も買っています」 に表示されている商品のURL
}


##################@buylistのReviewについて評価##################
my @itemgoodcnt =();
my @itembadcnt =();

my $buylistnum = scalar(@buylist);
my $n = 0;

foreach(@buylist){
    my $buyres = $ua->get($_);
    my $buycontent = $buyres->decoded_content;
    my $buytree = HTML::TreeBuilder->new;
    $buytree->parse($buycontent);

#商品URLからレビューのURLを取得
    my @review =  $buytree->look_down('class', 'histogramButton');

    my $itemreview ;
    my $itemgoodallcnt = 0;
    my $itembadallcnt = 0;
       
    if ($review[0]){#reviewが存在しないとき
        $itemreview = $review[0]->find("a")->attr('href');#商品のレビューのURL
        $html = HTML::TagParser->new( "$itemreview" );

        my $elem = $html->getElementsByTagName( "body" );

        my $text = $elem -> innerText();
        $text = decode('Shift_JIS', $text);
        chomp($text);
        $text = encode('UTF-8' , $text );

        my $title = $html->getElementsByTagName( "title" );
        $title =  $title-> innerText();
        $title = decode('Shift_JIS', $title);
        $title = encode('UTF-8' , $title );

        my $producttitle = "";
        if($title =~ m/カスタマーレビュー: /){
            $producttitle = "$'";#商品名を取得
            if($producttitle =~ m/\(|（|\[|［/ ){
                $producttitle = "$`";
                                       }
               }


               my $pre = "レビュー対象商品:";
               my $post = "レビューを評価してください";
               my $m = $buylistnum-$n;
               for(my $i = 0;$i < 10 ;$i++ ){
                   my $indirw = "";#individual review
                   my $nexttext = "";
                   if ($text =~ m/$pre/ ) {
                       $indirw = "$'";#$pre 以降

                       if($indirw =~ m/$post/){
                   #print "match:$`\n";
                           $indirw = "$`";#$post 以前
                           $nexttext = "$'";#次のtext
                   #print $nexttext,"\n";
                           $indirw =~ s/$producttitle//g;

                       }
                   }
                   $text = $nexttext;

                   my @file = ("./goodlist.txt","./badlist.txt");#商品を評価する良い表現と悪い表現

                   my $gallcnt = 0;
                   my $gfile = $file[0];
           open( my $gfh, "<", $gfile )
               or die "Cannot open $gfile: $!";

                   while( my $line = readline $gfh ){
               # readline関数で、一行読み込む。
               
                       chomp $line; # chomp関数で、改行を取り除く
               
                       my $str = $indirw;
                       my $cnt = (() = $str =~ /$line/g);
                       $gallcnt += $cnt;
                   }
                   $itemgoodallcnt += $gallcnt;#個々のレビューでのbadwordの数

                   close $gfh;

                   my $ballcnt = 0;
                   my $str = "";

                   my $bfile = $file[1];
           open( my $bfh, "<", $bfile )
               or die "Cannot open $bfile: $!";

                   while( my $line = readline $bfh ){
               # readline関数で、一行読み込む。
               
                       chomp $line; # chomp関数で、改行を取り除く
               
                       my $str = $indirw;
                       my $cnt = (() = $str =~ /$line/g);
                       $ballcnt += $cnt;

                   }

                   $itembadallcnt += $ballcnt;#個々のレビューでのbadwordの数

                   close $bfh;
               }
               push(@itemgoodcnt ,$itemgoodallcnt);
               push(@itembadcnt ,$itembadallcnt);
                }else{
                    push(@itemgoodcnt,"non");
                    push(@itembadcnt,"non");
       
                }
            $n++;
        }
        my %itemallcnt =();

        for (my $i =0; $i < scalar(@itemgoodcnt) ;$i++){
            if ($itemgoodcnt[$i] =~ /^[0-9]*$/) {
                $itemallcnt{"$buylist[$i]"} = $itemgoodcnt[$i] - $itembadcnt[$i];
            }
}



my @sorted_keys = sort { $itemallcnt{$b} <=> $itemallcnt{$a} || $a cmp $b }
keys %itemallcnt;


my @rankurl = ();
for my $key (@sorted_keys) {
   
    push(@rankurl, $key);
   
}

my $j = 1;

for(my $i = 0;$i < 5 ;$i++){
    $j = $i + 1;
    print "No.$j:$rankurl[$i]\n";
}
