sudo sed -i 's/^#\?minlen.*/minlen = 12/' /etc/security/pwquality.conf
sudo sed -i 's/^#\?dcredit.*/dcredit = -1/' /etc/security/pwquality.conf
sudo sed -i 's/^#\?ucredit.*/ucredit = -1/' /etc/security/pwquality.conf
sudo sed -i 's/^#\?lcredit.*/lcredit = -1/' /etc/security/pwquality.conf
sudo sed -i 's/^#\?ocredit.*/ocredit = -1/' /etc/security/pwquality.conf

set_pwq retry    3
set_pwq difok    4