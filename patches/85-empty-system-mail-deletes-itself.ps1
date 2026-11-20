# Letters from the game itself delete themselves once there is nothing left in them. The Postmaster (34337), the
# auction house, Manastorm, rewards and the other system senders leave a letter behind after you take its items or
# money, so the mailbox filled with hundreds of empty letters to delete by hand (James, 20 November). Now, for a letter
# not sent by a player (any sender type but a player's, or a player letter with no sender):
#   taking its last item or its money deletes it at once;
#   opening the mailbox deletes the ones already empty that you have read (so a text-only letter is read once, then goes).
# Letters from players are never touched, nor anything still holding items, money or a cash-on-delivery charge.
# Run by the build from the workspace root. Throws if an anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

function Edit-Core($file, $anchor, $replacement, $what) {
    $text = (Get-Content $file -Raw) -replace "`r`n", "`n"
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "Core changed: $what was not found exactly once in $file" }
    Set-Content $file $text.Replace($anchor, $replacement.Replace("`r`n", "`n")) -NoNewline
}

Write-Host "Patch: empty letters from the game delete themselves"
$file = 'core/src/server/game/Handlers/MailHandler.cpp'

$sendMail = "void WorldSession::HandleSendMail(WorldPacket& recvData)`n"
Edit-Core $file $sendMail (@'
// Wildcard: a letter from the game itself (not from a player) with nothing left in it.
static bool WcmeSpentSystemMail(Mail const* mail)
{
    return mail && mail->state != MAIL_STATE_DELETED && !mail->HasItems() && !mail->money && !mail->COD &&
        (mail->messageType != MAIL_NORMAL || !mail->sender);
}

// Wildcard: deletes it as the client's own Delete would; tells the client when it is on screen.
static void WcmeDropMail(Player* player, Mail* mail, bool tellClient)
{
    mail->state = MAIL_STATE_DELETED;
    player->m_mailsUpdated = true;
    sMailMgr->OnMailDeleted(player->GetGUID().GetCounter());
    if (tellClient)
        player->SendMailResult(mail->messageID, MAIL_DELETED, MAIL_OK);
}

'@ + $sendMail) 'WorldSession::HandleSendMail'

$takeItem = "        sScriptMgr->OnPlayerTakeMailItem(player, m, itemEntry);`n"
Edit-Core $file $takeItem ($takeItem + @'
        if (WcmeSpentSystemMail(m)) // Wildcard: the last item out of a letter from the game
            WcmeDropMail(player, m, true);
'@) 'the mail item taken in WorldSession::HandleMailTakeItem'

$takeMoney = "    player->SaveGoldToDB(trans);`n    player->_SaveMail(trans);`n    CharacterDatabase.CommitTransaction(trans);`n}`n`n//called when player lists his received mails`n"
Edit-Core $file $takeMoney (@'
    player->SaveGoldToDB(trans);
    player->_SaveMail(trans);
    CharacterDatabase.CommitTransaction(trans);

    if (WcmeSpentSystemMail(m)) // Wildcard: the money out of a letter from the game
        WcmeDropMail(player, m, true);
}

//called when player lists his received mails

'@) 'the end of WorldSession::HandleMailTakeMoney'

$list = "    LocalLevelScaling::NotifyMailListed(player);`n"
Edit-Core $file $list ($list + @'
    // Wildcard: letters from the game already emptied and read go before the list is sent.
    for (Mail* mail : player->GetMails())
        if (WcmeSpentSystemMail(mail) && (mail->checked & MAIL_CHECK_MASK_READ))
            WcmeDropMail(player, mail, false);
'@) 'the mailbox listing in WorldSession::HandleGetMailList'
