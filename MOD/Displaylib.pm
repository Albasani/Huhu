######################################################################
#
# $Id: Displaylib.pm 305 2011-12-26 19:51:53Z root $
#
# Copyright 2007-2009 Roman Racine
# Copyright 2009-2011 Alexander Bartolich
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
######################################################################
package MOD::Displaylib;

use strict;
use warnings;
use Carp qw( confess );

use Mail::Mailer();
use News::Article();
use News::Article::Response();
use MIME::QuotedPrint();
use MIME::Base64();
use Encode();
use CGI();
use CGI::Pretty();

use MOD::DBIUtilsPublic;
use MOD::Utils;

use constant VERSION => 0.09;

use constant MENU_MESSAGES => [
  [ 'pending', 'Pending' ],
  [ 'spam', 'Spam' ],
  [ 'moderated', 'Approved' ],
  [ 'posted', 'Posted' ],
  [ 'rejected', 'Rejected' ],
  [ 'deleted', 'Deleted' ],
  [ 'errors', 'Error Messages' ],
];
use constant MENU_CONFIGURATION => undef;

use constant MENU_MAIN => [
  [ 'pending', 'Messages', MENU_MESSAGES ],
  [ 'config', 'Configuration', MENU_CONFIGURATION ],
];

######################################################################
sub new($$$)
######################################################################
{
  my ($class, $configref, $privileged) = @_;
  my $self = {};

  $self->{'db'} = MOD::DBIUtilsPublic->new($configref);
  my $q = $self->{'q'} = CGI->new();

  my $self_url = $q->self_url;
  $self_url =~ s/\?+.+$//;
  $self->{'self_url'} = $self_url;

  $self->{'config'} = $configref;
  $self->{'privileged'} = $privileged;

  my $lang = MOD::Utils::get_translator_language(
    $configref->{'html_language'},
    $configref->{'http_negotiate_language'}
  );
  $self->{'trans_lang'} = $lang;
  $self->{'trans'} = MOD::Utils::get_translator($lang);

  if ($privileged)
  {
    my $authentication = $configref->{'http_authentication_method'};
    die "No 'http_authentication_method' in configuration file." unless($authentication);

    if ($q->auth_type() && $q->auth_type() eq $authentication)
    {
      $self->{'user_name'} = $q->remote_user();
    }
    elsif ($authentication eq 'None')
    {
      $self->{'user_name'} = $q->remote_host();
    }
    die 'Not authorized' unless($self->{'user_name'});
  }

  bless $self, $class;
  return $self;
}

######################################################################
sub display_start($;$$$@)
######################################################################
{
  my $self = shift;
  my %args = @_;

  my $trans = $self->{'trans'} || confess 'No translator';
  my $title = $args{'-title'} || confess 'No -title';
  $title = $trans->($title);

  my $group = $self->{'config'}->{'moderated_group'};
  my @title;
  push @title, '[*]' if ( $args{'-mark'} );
  push @title, $group if ($group);
  push @title, $title if ($title);

  my $q = $self->{'q'};
  my @head = ($q->meta({
    -http_equiv => 'expires',
    -content    => '0'
  }));

  my $refresh = $args{'-refresh'};
  if ($refresh)
  {
    push @head, $q->meta({
      -http_equiv => 'Refresh',
      -content    => $refresh
    });
  }

  my @param = (
    -title => join(' ', @title),
    -head => \@head
  );

  my $css = $self->{'config'}->{'html_stylesheet_href'};
  if ($css)
    { push @param, -style => { -src => $css }; }

  print
    $q->header,
    $q->start_html( @param );
  $self->print_menu_items() if ($self->{'privileged'});

  print '<div class="huhuContents">';
  print $q->h1($title);
  my $subtitle = $args{'-subtitle'};
  if ($subtitle)
  {
    printf '<div class="huhuSubtitle">%s</div>', $trans->($subtitle);
  }
}

######################################################################
sub display_end($)
######################################################################
{
  my ($self) = @_;

  my $group = $self->{'config'}->{'moderated_group'};
  my $user = $self->{'user_name'};

  my @a;
  push @a, $group if ($group);
  push @a, $self->{'trans_lang'};
  push @a, $user if ($user);
  push @a, 'huhu version ' . VERSION;

  print
    '<div class="huhuVersion">',
    join('&nbsp;&middot;&nbsp;', @a),
    '.</div>',
    '</div><!-- class="huhuContents" -->',
    $self->{'q'}->end_html;
}

######################################################################
sub display_die_msg($$$)
######################################################################
{
  my ($self, $title, $msg) = @_;
  my $trans = $self->{'trans'} || confess 'No translator';

  $self->display_start(-title => 'Error');
  print '<div class="huhuError">',
        $trans->($msg ? $msg : $title),
	'</div>';
  $self->display_end();
}

######################################################################
sub display_table($@)
######################################################################
{
  my $self = shift || confess 'No $self';
  my %args = @_;

  my $status = $args{'-status'} || confess 'No -status';
  my $start = $args{'-start'}; # can be 0
  my $no_of_elements = $args{'-no_of_elements'} || confess 'No -no_of_elements';
  my $overviewref = $args{'-overviewref'} || confess 'No -overviewref';
  my $decisionref = $args{'-decisionref'} || confess 'No -decisionref';
  my $cmd = $args{'-cmd'};

  my @hidden_columns = ( 'flag', 'id' );
  {
    my $extra_hidden_columns = $args{'-hiddencolumns'};
    if ($extra_hidden_columns) {
      push @hidden_columns, @$extra_hidden_columns;
    }
  }
  my @columns = ( @hidden_columns, @$overviewref );

  my $db = $self->{'db'} || confess 'No "db" in $self';

  my $dataref;
  if ($status eq 'errors' and $self->{'privileged'}) {
      $dataref = $db->display_errors($status,$start,$no_of_elements,\@columns);
  } else {
      $dataref = $db->displayrange($status,$start,$no_of_elements,\@columns);
  }

  my $trans = $self->{'trans'} || confess 'No translator';
  my $sqlnames = $dataref->{'NAME'} || confess 'No "NAME" in $dataref';
  my @names = map { CGI::escapeHTML($trans->( $_ )) } (
    @$sqlnames[1 + $#hidden_columns .. $#$sqlnames],
    'Available Actions'
  );

  my $ref = $dataref->fetchrow_arrayref();
  my $q = $self->{'q'} || confess 'No "q" in $self';

  $self->display_start(
    -title => $args{'-title'},
    -subtitle => $args{'-subtitle'},
    -mark => $ref && $self->{'privileged'},
    -refresh => '300; ' . $q->url() . '?' . $cmd
  );

  print '<table class="huhuPostList">';
  print $q->Tr($q->th({-align=>'left'},\@names));

  my $css = $self->{'config'}->{'html_stylesheet_href'};
  my $flagattr = ($css) ? ' class="huhuFlag"' : ' bgcolor="#ffcccc"';

  my $row_nr = 0;
  if ($ref) {
    do {
      $row_nr++;
      my @dataline = @{$ref};
      my $flag = $dataline[0];
      my $rowattr = ($flag and $self->{'privileged'})
      ? $flagattr
      : ($row_nr % 2)
      ? ' class="huhuOdd"'
      : ' class="huhuEven"';

      my $id = $dataline[1];
      print "<tr$rowattr>";
      for my $i(1 + $#hidden_columns .. $#dataline) {
        my $data = $dataline[$i];
        $data = CGI::escapeHTML(substr($self->decode_line($data),0,40));
        $data =~ s/\@/#/g if (!defined($self->{'user_name'}));
        print $q->td($data);
      }
      print'<td>';
      $self->display_decisionbuttons($decisionref, $ref, \@hidden_columns);
      print '</td></tr>',"\n";
     } while ($ref = $dataref->fetchrow_arrayref);
  }

  if ($row_nr == 0)
  {
    printf '<tr><td class="huhuNoRows" colspan="%d">', 1 + $#names;
    print  $trans->('No matching records available.');
    print '</td></tr>';
  }

  print "</table>\n";
  $self->nextpage($cmd, $start, $args{'-display_per_page'});

  $self->display_end();
  return;
}

sub display_reason {
  my ($self,$id,$decisionref,$title) = @_;
  my $dataref = $self->{'db'}->get_reason($id);
  my $reason;
  eval {
    ($reason) = @{$dataref->fetchrow_arrayref};
  }; if ($@) {
     $self->display_die_msg('No reason stored in database!');
     return;
  }

  $self->display_start(-title => $title);

  print
    '<div class="huhuReason">',
    '<pre width="100">', CGI::escapeHTML($reason), '</pre>',
    '</div>';
  $self->display_decisionbuttons($decisionref, [ $id ]);
  print $self->{'q'}->end_html;
  return;
}

sub display_navigation_back() {
  my ($self) = @_;
  my $q = $self->{'q'} || confess 'No q';
  my $trans = $self->{'trans'} || confess 'No translator';
  print
    '<div class="huhuNavigation">',
    '<span>', 
    $q->a({ href => $q->referer() }, $trans->('Back')),
    '</span>',
    '</div>';
}

sub display_article_info($$$)
{
  my ( $self, $sqlnames, $row ) = @_;

  $sqlnames || confess 'No "NAME" in $dataref';
  $row || confess 'No $row';
  $#$row == $#$sqlnames || confess '$#$row != $#$sqlnames';

  my @a;
  for(my $i = 1; $i <= $#$row; $i++)
  {
    my $value = $row->[$i];
    if ($value)
    {
      push @a,
	CGI::escapeHTML($sqlnames->[$i]) .
	': ' .
	CGI::escapeHTML($value);
    }
  }
  if (@a)
  {
    print
      '<div class="huhuArticleInfo">',
      join('&nbsp;&middot;&nbsp;', @a),
      '</div>';
  }
}
 
######################################################################
sub display_article($@)
######################################################################
{
  my $self = shift || confess 'No $self';
  my %args = @_;

  my $status = $args{'-status'};
  my $id = $args{'-id'};
  my $headerref = $args{'-headerref'};
  my $decisionref = $args{'-decisionref'};
  my $fullheader = $args{'-fullheader'};

  if ($status eq 'errors') {
    $status = undef;
  }

  my $dataref = $self->{'db'}->display_single($status,$id);
  my $row = $dataref->fetchrow_arrayref;
  if (!$row || $#$row < 1) {
    $self->display_die_msg('_ALREADY_HANDLED' . " (status=$status, id=$id)");
    return;
  }

  my $article = $self->decode_article(News::Article->new(\$row->[0]));

  $self->display_start(-title => 'Selected Article');
  $self->display_article_info($dataref->{'NAME'}, $row);
  my $q = $self->{'q'} || confess 'No "q" in $self';

  print '<table class="huhuArticle">';
  if ($fullheader) {
     my $header = join "\n",$article->headers();
     print $q->Tr($q->td({-colspan=>2},'<pre width="100">' . CGI::escapeHTML($header) .'</pre>'));
  } else {
    for my $headerline (@{$headerref}) {
      print
	'<tr class="huhuArticleHeader">',
	'<th>', CGI::escapeHTML($headerline), '</th>',
	'<td>', CGI::escapeHTML($article->header($headerline)), '</td>',
	'</tr>';
    }
  }
  my @ngs = split ',', $article->header('Newsgroups');
  if ($self->{'user_name'} && @ngs > 2)
  {
    my $trans = $self->{'trans'} || confess 'No translator';
    print $q->Tr($q->td(
      {-colspan=>2,-bgcolor=>'#ffcccc'},
      $trans->( '_CROSSPOSTED' )
    ));
  }

  print $q->Tr($q->td({-colspan=>2},
		      '<pre width="100">' . CGI::escapeHTML(join ("\n",$article->body())) . '</pre>')),
       '</table><table class="huhuDecisionButtons"><tr><td>';
  $self->display_decisionbuttons($decisionref, [ $id ]);
  print "</td></tr>\n</table>";

  $self->display_navigation_back();
  print $q->end_html;
  return;
}

######################################################################
sub display_errormessage($$$)
######################################################################
{
  my ($self, $id, $title) = @_;
  my $dataref = $self->{'db'}->get_errormessage($id);
  my $input;
  eval {
    ($input) = @{$dataref->fetchrow_arrayref};
  }; if ($@) {
    $self->display_die_msg('_ERROR_GONE');
    return;
  }

  $self->display_start(-title => $title);
  my $q = $self->{'q'};

  print '<div class="huhuErrorMessage"><pre>',
        CGI::escapeHTML($input),
	'</pre></div>';
  $self->display_navigation_back();
  print $q->end_html;
  return;
}

######################################################################
sub generate_answer($$$$)
######################################################################
{
  my ($self, $id, $behaviour, $title) = @_;
  my $db = $self->{'db'} || confess 'No "db" in $self';
  my $trans = $self->{'trans'} || confess 'No translator';
  my $q = $self->{'q'} || confess 'No q';

  # first of all move the article out of the pending queue
  $db->set_status_by_moderator('deleted', $id, $self->{'user_name'});

  my $dataref = $db->get_working_by_id($id);
  my ($input,$addr);
  eval {
    ($input,$addr) = @{$dataref->fetchrow_arrayref};
  }; if ($@) {
    $self->display_die_msg('_ALREADY_HANDLED');
    return;
  }
  my $article = $self->decode_article(News::Article->new(\$input));

  my $attribution = sprintf(
    $trans->('%s wrote:'),
    $article->header('From')
  );

  my $response = News::Article->response(
    $article,
    {
      'From' => $self->{'config'}->{'mailfrom'},
    },
    'respstring' => sub { return $attribution; }
  );

  my $body = join ("\n",$response->body());
  $self->display_start(-title => $title);

  if ($behaviour eq 'answer')
  {
    print
      $q->start_form,
      $q->hidden(-name => 'id', -value => $id),
      $q->table
      (
        $q->Tr([
	  $q->td(['From', $self->{'config'}->{'mailfrom'}]),
          $q->td(['To', CGI::escapeHTML($addr)]),
          $q->td(['Subject', CGI::escapeHTML($response->header('Subject'))]),
          $q->td(
	    { -colspan => 2},
            $q->textarea({
	      -name =>'antwort',
              -cols => 80,
              -rows => 40,
              -default => $body,
              -wrap => 'hard'
            })
          ),
          $q->td(
	    { -colspan => 2 },
            $q->submit(
	      -name => 'action.Send Mail',
	      -value => $trans->('Send Mail')
	    ),
	    $q->submit(
	      -name => 'action.Put back in queue',
	      -value => $trans->('Put back in queue')
	    )
	  )
        ])
      ),
      $q->end_form;
  }
  else
  {
    print
      $trans->('_EXPLAIN_REASON'),
      $q->start_form,
      $q->hidden({ -name => 'id', -value => $id }),
      $q->textarea({
        -name => 'antwort',
	-cols => 80,
	-rows => 40,
	-default => $body,
	-wrap => 'hard'
      }),
      '<br/>',
      $q->submit(
	-name => 'action.Delete and save reason',
	-value => $trans->('Delete and save reason')
      ),
      $q->submit(
	-name => 'action.Put back in queue',
	-value => $trans->('Put back in queue')
      ),
      $q->end_form;
  }
  print $q->end_html;
  return;
}

######################################################################
sub delete_posting
######################################################################
{
  my ($self,$id) = @_;
  my $antwort = $self->{'q'}->param('antwort');
  $antwort =~ s/\&gt;/>/sg;
  $antwort =~ s/\&lt;/</sg;
  $antwort =~ s/\&amp;/&/sg;
  $self->{'db'}->set_rejected('deleted', $id, $self->{'user_name'}, $antwort);
  return;
}

######################################################################
sub send_mail($$)
######################################################################
{
  my ($self,$id) = @_;
  my $antwort = $self->{'q'}->param('antwort');
  $antwort =~ s/\&gt;/>/sg;
  $antwort =~ s/\&lt;/</sg; 
  $antwort =~ s/\&amp;/&/sg;

  my $trans = $self->{'trans'} || confess 'No translator';

  my $dataref = $self->{'db'}->get_working_by_id($id);
  my ($input,$addr);
  eval {
    ($input,$addr) = @{$dataref->fetchrow_arrayref};
  }; if ($@) {
    $self->display_die_msg('_ALREADY_HANDLED');
    return 0;
  }

  my $article = News::Article->new(\$input);
  my $original_subject = $article->header('Subject');
  if (!$original_subject)
    { $original_subject = $trans->('No subject'); }

  $article = $self->decode_article($article);
  if ($addr =~ /(,|\n)/s or $addr =~ /invalid>$/) {
    $self->display_die_msg('_ERROR_INVALID_ADDRESS');
    return 0;
  }
  my $mailer = new Mail::Mailer;

  my $subject_prefix = $trans->('Your post regarding');
  $original_subject =~ s/(AW|Re):\s*$subject_prefix\s*/Re:/i;

  $mailer->open({
    'From' => $self->{'config'}->{'mailfrom'},
    'Subject' => $subject_prefix . ' ' . $original_subject,
    'To' => $addr,
    'Content-Type' => "text/plain;\n  charset=\"". $self->{'config'}->{'html_content_type'}. '"',
    'Content-Transfer-Encoding' => '8bit'
  });
  print $mailer $antwort;
  $mailer->close();
  $self->{'db'}->set_rejected('rejected', $id, $self->{'user_name'}, $antwort);
  return 1;
}

######################################################################
sub display_decisionbuttons
######################################################################
{
  my ($self, $decisionref, $hidden_values, $hidden_names) = @_;

  $hidden_names = [ 'id' ] unless($hidden_names);

  my $q = $self->{'q'} || confess 'No "q" in $self';
  my $trans = $self->{'trans'} || confess 'No translator';

  print $q->start_form;
  for(my $i = 0; $i <= $#$hidden_names; $i++)
  {
    printf
      '<input type="hidden" name="%s" value="%s"/>',
      $hidden_names->[$i], $hidden_values->[$i];
  }
  for my $decision (@{$decisionref})
  {
    print $q->submit(
      -name => 'action.' . $decision,
      -label => CGI::escapeHTML($trans->($decision))
    );
  }
  print $q->end_form;
  return;
}


sub nextpage {
  my ($self, $cmd, $start, $display_per_page) = @_;

  my $q = $self->{'q'} || confess 'No "q" in $self';
  $cmd || confess 'No $cmd';
  my $trans = $self->{'trans'} || confess 'No translator';

  if (!defined($display_per_page) || $display_per_page !~ /^\d+$/)
  {
    $display_per_page = $self->{'config'}->{'display_per_page'};
  }
  $start = 0 if ($start !~ /^\d+$/);

  my $before = $start - $display_per_page;
  my $next = $start + $display_per_page;
  $before = 0 if ($before < 0);
  my $self_url = $self->{'self_url'} || confess;

  print '<div class="huhuNavigation"><span>', 
        $q->a(
	  { href => $self_url . '?'. $cmd . ',' . $before },
	  $trans->('Previous page')
	),
        '</span><span>',
	$q->a(
	  { href => $self_url . '?'. $cmd . ',' . $next },
	  $trans->('Next page')
	),
        '</span></div>';
  return;
}

######################################################################
sub print_menu_items($$$)
######################################################################
{
  my $self = shift || confess;
  my $r_items = shift || MENU_MAIN;
  my $level = shift || 0;

  my $self_url = $self->{'self_url'} || confess;
  my $trans = $self->{'trans'} || confess 'No translator';

  printf '<ul class="huhuMainMenu%d">', $level;
  for my $r_definition(@$r_items)
  {
    my $submenu = $r_definition->[2];
    printf
      '<li><span><a href="%s">%s</a></span>',
      $self_url . '?' . $r_definition->[0],
      $trans->( $r_definition->[1] );
    if ($submenu)
    {
      $self->print_menu_items($submenu, $level + 1);
    }
    print '</li>';
  }
  print '</ul>';
}

sub set_status_by_moderator {
  my ($self, $newstatus, $id) = @_;
  $self->{'db'}->set_status_by_moderator($newstatus, $id, $self->{'user_name'});
  return;
}

sub post {
  my ($self,$id) = @_; 
  $self->{'db'}->set_status_posted($id, $self->{'user_name'});
  return;
}

sub decode_article {
  my ($self, $article) = @_;

  $self || confess 'No $self';
  $article || confess 'No $article';

  for my $headerline (qw(Subject From Reply-To)) {
    $article->set_headers($headerline,$self->decode_line($article->header($headerline)));
  }

  my $body = join "\n",$article->body();

  if (defined($article->header('Content-Transfer-Encoding')) and
      $article->header('Content-Transfer-Encoding') eq 'quoted-printable') {
    $body =  MIME::QuotedPrint::decode($body);
  }
  my $encoding;
  if (defined($article->header('Content-Type')) and
      $article->header('Content-Type') =~ m|^text/plain;.+charset=[\s"]*([\w-]+)[\s"]?|si) {
      $encoding = $1;
  } else {
      $encoding = 'iso-8859-1';
  }
  eval {
    if (Encode::find_encoding($encoding)->perlio_ok) {
	Encode::from_to($body,$encoding,$self->{'config'}->{'html_content_type'});
    }
  };
  $article->set_body(($body));
  return $article;
}

sub decode_line {
  my ($self,$line) = @_;
  if (!$self->{'privileged'}) {
    $line =~ s/\@/#/g;
  }
  my $newline;
  while ($line =~ s/^(.*?)=\?([^?]+)\?(.)\?([^?]*)\?=(?:\r?\n +)?//s) {
    my ($before,$charset,$encoding,$content) = ($1,$2,lc($3),$4);
    $newline .= $before;
    if ($encoding eq 'q') {
        $content =~ s/_/ /g;
        $content = MIME::QuotedPrint::decode($content);
        chomp $content;
    } elsif ($encoding eq 'b') {
        $content = MIME::Base64::decode($content);
    }
    eval {
      if (Encode::find_encoding($charset)->perlio_ok) {
          Encode::from_to($content,$charset,$self->{'config'}->{'html_content_type'});
      }
    };
    $newline .= $content;
  }
  $newline .= $line;
  return $newline;
}

sub set_flag {
  my ($self,$id) = @_;
  $self->{'db'}->invert_flag($id);
  return;
}

use constant SHOW_CONFIG => (
  'approve_string',
  'check_duplicates_age',
  'display_per_page',
  'followup_to',
  'html_content_type',
  'http_authentication_method',
  'http_negotiate_language',
  'mailfrom',
  'moderated_group',
  'mysql_host',
  'mysql_port',
  'mysql_username',
);

######################################################################
sub display_config($)
######################################################################
{
  my $self = shift || confess;

  my $q = $self->{'q'} || confess 'No "q" in $self';
  my $trans = $self->{'trans'} || confess 'No "trans" in $self';
  my $config = $self->{'config'} || confess 'No "config" in $self';

  $self->display_start(
    -title => $trans->('Configuration'),
    # -subtitle => $args{'-subtitle'},
    -mark => 0,
    # -refresh => '300; ' . $q->url() . '?' . $cmd
  );
  
  print '<table class="huhuPostList">';
  print $q->Tr($q->th({-align=>'left'}, [ 'Key', 'Value' ]));

  my @key = SHOW_CONFIG;
  for my $key(@key)
  {
    printf "<tr><td>%s</td><td>%s</td></tr>", $key, $config->{$key};
  }
  print "</table>";

  $self->display_end();
}

######################################################################
1;
######################################################################
