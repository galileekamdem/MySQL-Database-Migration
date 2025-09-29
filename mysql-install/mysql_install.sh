#!/bin/bash

# Script d'installation automatisée MySQL/Apache/PHP sur Ubuntu EC2
# Version corrigée pour gérer l'authentification MySQL moderne

set -e  # Arrêter le script en cas d'erreur

echo "=== Début de l'installation LAMP Stack ==="

# Mise à jour du système
echo "Mise à jour du système..."
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Installation d'Apache
echo "Installation d'Apache..."
sudo apt-get install apache2 -y
sudo systemctl start apache2
sudo systemctl enable apache2

# Installation de MySQL Server avec configuration automatique du mot de passe root
echo "Installation de MySQL Server..."
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password RootPassword123!'
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password RootPassword123!'
sudo DEBIAN_FRONTEND=noninteractive apt-get install mysql-server -y
sudo systemctl start mysql
sudo systemctl enable mysql

# Attendre que MySQL soit complètement démarré
echo "Attente du démarrage complet de MySQL..."
sleep 15

# Vérifier si MySQL utilise auth_socket ou mot de passe
echo "Vérification de l'authentification MySQL..."
MYSQL_AUTH_METHOD=$(sudo mysql -e "SELECT plugin FROM mysql.user WHERE User='root' AND Host='localhost';" 2>/dev/null | tail -1 || echo "auth_socket")

if [[ "$MYSQL_AUTH_METHOD" == "auth_socket" ]]; then
    echo "MySQL utilise auth_socket, configuration sans mot de passe initial..."
    # Configuration sécurisée de MySQL avec auth_socket
    sudo mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'RootPassword123!';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
else
    echo "MySQL utilise l'authentification par mot de passe..."
    # Configuration sécurisée avec mot de passe
    mysql -u root -pRootPassword123! <<EOF
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
fi

# Variables de la base de données
DB_NAME="Demo"
DB_USER="Lab"
DB_PASSWORD="Lab123"

echo "Création de la base de données et de l'utilisateur..."
mysql -u root -pRootPassword123! <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

# Installation de PHP et modules
echo "Installation de PHP et modules..."
sudo apt-get install php libapache2-mod-php php-mysql php-mbstring php-zip php-gd php-json php-curl -y

# Pré-configuration de phpMyAdmin pour éviter les prompts interactifs
echo "Pré-configuration de phpMyAdmin..."
sudo debconf-set-selections <<< 'phpmyadmin phpmyadmin/dbconfig-install boolean true'
sudo debconf-set-selections <<< 'phpmyadmin phpmyadmin/app-password-confirm password Lab123'
sudo debconf-set-selections <<< 'phpmyadmin phpmyadmin/mysql/admin-pass password RootPassword123!'
sudo debconf-set-selections <<< 'phpmyadmin phpmyadmin/mysql/app-pass password Lab123'
sudo debconf-set-selections <<< 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2'

# Installation de phpMyAdmin
echo "Installation de phpMyAdmin..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install phpmyadmin -y

# Vérifier si phpMyAdmin est installé et créer le lien approprié
if [ -d "/usr/share/phpmyadmin" ]; then
    echo "Configuration de phpMyAdmin..."
    sudo ln -sf /usr/share/phpmyadmin /var/www/html/phpmyadmin
elif [ -d "/var/lib/phpmyadmin" ]; then
    echo "Configuration alternative de phpMyAdmin..."
    sudo ln -sf /var/lib/phpmyadmin /var/www/html/phpmyadmin
else
    echo "Réinstallation de phpMyAdmin..."
    sudo apt-get install --reinstall phpmyadmin -y
    sudo ln -sf /usr/share/phpmyadmin /var/www/html/phpmyadmin
fi

# Configuration Apache pour phpMyAdmin
echo "Configuration Apache pour phpMyAdmin..."

# Créer la configuration phpMyAdmin compatible avec PHP 8.x
sudo tee /etc/apache2/conf-available/phpmyadmin.conf > /dev/null <<EOF
# phpMyAdmin Apache configuration

Alias /phpmyadmin /usr/share/phpmyadmin

<Directory /usr/share/phpmyadmin>
    Options FollowSymLinks
    DirectoryIndex index.php
    AllowOverride None
    Require all granted

    # PHP 8.x configuration
    <IfModule mod_php.c>
        php_admin_value upload_tmp_dir /var/lib/phpmyadmin/tmp
        php_admin_value open_basedir /usr/share/phpmyadmin/:/tmp/:/var/lib/phpmyadmin/:/etc/phpmyadmin/:/usr/share/php/
    </IfModule>
</Directory>

# Restrict access to setup directory
<Directory /usr/share/phpmyadmin/setup>
    Require ip 127.0.0.1
    Require ip ::1
</Directory>

# Deny access to sensitive directories
<Directory /usr/share/phpmyadmin/templates>
    Require all denied
</Directory>
<Directory /usr/share/phpmyadmin/libraries>
    Require all denied
</Directory>
<Directory /usr/share/phpmyadmin/setup/lib>
    Require all denied
</Directory>
EOF

# Configuration phpMyAdmin pour corriger les erreurs communes
echo "Configuration de phpMyAdmin..."
sudo tee /etc/phpmyadmin/conf-local.php > /dev/null <<EOF
<?php
// Configuration locale pour phpMyAdmin

// Configuration de base
\$cfg['blowfish_secret'] = '$(openssl rand -base64 32)';
\$cfg['DefaultLang'] = 'fr';
\$cfg['ServerDefault'] = 1;

// Configuration serveur MySQL
\$i = 0;
\$i++;
\$cfg['Servers'][\$i]['auth_type'] = 'cookie';
\$cfg['Servers'][\$i]['host'] = 'localhost';
\$cfg['Servers'][\$i]['compress'] = false;
\$cfg['Servers'][\$i]['AllowNoPassword'] = false;

// Répertoires temporaires
\$cfg['TempDir'] = '/var/lib/phpmyadmin/tmp/';
\$cfg['UploadDir'] = '/var/lib/phpmyadmin/tmp/';
\$cfg['SaveDir'] = '/var/lib/phpmyadmin/tmp/';

// Désactiver les avertissements
\$cfg['SendErrorReports'] = 'never';
\$cfg['CheckConfigurationPermissions'] = false;
?>
EOF

# Activer la configuration phpMyAdmin
sudo a2enconf phpmyadmin

# Activer les modules PHP nécessaires
sudo phpenmod mbstring
sudo a2enmod rewrite

# Créer le répertoire tmp pour phpMyAdmin si nécessaire
sudo mkdir -p /var/lib/phpmyadmin/tmp
sudo chown -R www-data:www-data /var/lib/phpmyadmin
sudo chmod -R 755 /var/lib/phpmyadmin

# Corriger les permissions phpMyAdmin
sudo chown -R root:www-data /usr/share/phpmyadmin
sudo find /usr/share/phpmyadmin -type d -exec chmod 755 {} \;
sudo find /usr/share/phpmyadmin -type f -exec chmod 644 {} \;

# Vérifier et corriger la configuration PHP
echo "Configuration PHP pour phpMyAdmin..."
sudo tee -a /etc/php/*/apache2/conf.d/99-phpmyadmin.ini > /dev/null <<EOF
; Configuration phpMyAdmin
max_execution_time = 300
max_input_vars = 5000
memory_limit = 128M
post_max_size = 50M
upload_max_filesize = 50M
session.gc_maxlifetime = 1440
EOF

# S'assurer que les extensions PHP nécessaires sont activées
sudo phpenmod mysqli
sudo phpenmod json
sudo phpenmod mbstring

# Configuration MySQL pour accepter les connexions externes
echo "Configuration de MySQL pour les connexions externes..."
sudo sed -i "s/bind-address\s*=.*/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf

# Redémarrage des services
echo "Redémarrage des services..."
sudo systemctl restart apache2
sudo systemctl restart mysql

# Test de la configuration Apache
echo "Test de la configuration Apache..."
if sudo apache2ctl configtest; then
    echo "✓ Configuration Apache valide"
else
    echo "✗ Problème de configuration Apache"
    sudo apache2ctl configtest
fi

# Vérifier les logs d'erreurs phpMyAdmin
echo "Vérification des permissions et logs..."
if [ -f "/var/log/apache2/error.log" ]; then
    echo "Dernières erreurs Apache (si elles existent):"
    sudo tail -n 5 /var/log/apache2/error.log 2>/dev/null || echo "Aucune erreur récente"
fi

# Vérification du statut des services
echo "Vérification du statut des services..."
if sudo systemctl is-active --quiet apache2; then
    echo "✓ Apache est actif"
else
    echo "✗ Problème avec Apache"
    sudo systemctl status apache2
fi

if sudo systemctl is-active --quiet mysql; then
    echo "✓ MySQL est actif"
else
    echo "✗ Problème avec MySQL"
    sudo systemctl status mysql
fi

# Test de la connexion MySQL
echo "Test de la connexion MySQL..."
if mysql -u root -pRootPassword123! -e "SELECT 'Connexion MySQL OK' as test;" 2>/dev/null; then
    echo "✓ Connexion MySQL root réussie"
else
    echo "✗ Problème de connexion MySQL root"
fi

# Récupération de l'IP publique (avec gestion d'erreur)
echo "Récupération de l'IP publique..."
PUBLIC_IP=$(curl -s --connect-timeout 10 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "IP_NON_DISPONIBLE")

# Création d'une page de test PHP
echo "Création d'une page de test..."
sudo tee /var/www/html/test.php > /dev/null <<EOF
<?php
echo "<h1>Test LAMP Stack</h1>";
echo "<p>PHP Version: " . phpversion() . "</p>";

// Test de connexion MySQL
\$servername = "localhost";
\$username = "${DB_USER}";
\$password = "${DB_PASSWORD}";
\$dbname = "${DB_NAME}";

try {
    \$pdo = new PDO("mysql:host=\$servername;dbname=\$dbname", \$username, \$password);
    \$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "<p>✓ Connexion MySQL réussie à la base '\$dbname'</p>";
} catch(PDOException \$e) {
    echo "<p>✗ Erreur de connexion MySQL: " . \$e->getMessage() . "</p>";
}

// Vérification phpMyAdmin
if (file_exists('/usr/share/phpmyadmin/index.php')) {
    echo "<p>✓ phpMyAdmin installé</p>";
} else {
    echo "<p>✗ phpMyAdmin non trouvé</p>";
}

phpinfo();
?>
EOF

# Création d'une page d'accueil
sudo tee /var/www/html/index.html > /dev/null <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>LAMP Stack - Installation Réussie</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .success { color: green; }
        .info { background: #f0f0f0; padding: 20px; margin: 20px 0; }
    </style>
</head>
<body>
    <h1 class="success">🎉 Installation LAMP Stack Réussie!</h1>
    
    <div class="info">
        <h3>Liens utiles:</h3>
        <ul>
            <li><a href="/test.php" target="_blank">Page de test PHP</a></li>
            <li><a href="/phpmyadmin" target="_blank">phpMyAdmin</a></li>
        </ul>
        
        <h3>Informations de connexion MySQL:</h3>
        <ul>
            <li>Base de données: ${DB_NAME}</li>
            <li>Utilisateur: ${DB_USER}</li>
            <li>Mot de passe: ${DB_PASSWORD}</li>
        </ul>
    </div>
</body>
</html>
EOF

# Ajustement des permissions
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html

echo ""
echo "=== Installation terminée avec succès! ==="
echo ""
echo "Informations de connexion:"
echo "- Base de données: ${DB_NAME}"
echo "- Utilisateur DB: ${DB_USER}"
echo "- Mot de passe DB: ${DB_PASSWORD}"
echo "- Root MySQL: RootPassword123!"
echo ""
echo "URLs d'accès:"
if [ "$PUBLIC_IP" != "IP_NON_DISPONIBLE" ]; then
    echo "- Site web: http://${PUBLIC_IP}/"
    echo "- Page de test: http://${PUBLIC_IP}/test.php"
    echo "- phpMyAdmin: http://${PUBLIC_IP}/phpmyadmin"
else
    echo "- Utilisez l'IP publique de votre instance EC2"
    echo "- Page de test: http://[VOTRE_IP]/test.php"
    echo "- phpMyAdmin: http://[VOTRE_IP]/phpmyadmin"
fi
echo ""
echo "Note: Assurez-vous que les ports 80 et 3306 sont ouverts dans votre Security Group AWS"