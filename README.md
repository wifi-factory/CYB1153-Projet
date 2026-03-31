# CYB1153 - Projet AWS Annuaire

Depot GitHub : [wifi-factory/CYB1153-Projet](https://github.com/wifi-factory/CYB1153-Projet)

Ce depot fournit une base propre, reproductible et sans secret pour recreer le projet universitaire CYB1153 de deploiement d'un annuaire des employees sur AWS. Le contenu reste volontairement pedagogique : simple a lire, simple a adapter, et coherent avec l'architecture demandee dans le cours.

## Objectif du projet

Le projet cible une architecture AWS en `us-east-1` composee de :

- un Application Load Balancer ;
- deux instances EC2 `t2.micro` dans deux zones de disponibilite distinctes ;
- une application PHP/Apache accessible via `/SamplePage.php` ;
- une base de donnees RDS MySQL `tutorial-db-instance` ;
- un site statique S3 accessible via `/index.html` ;
- un dashboard CloudWatch avec `RequestCount`, `DatabaseConnections`, `NumberOfObjects` et `CPUUtilization` ;
- trois Security Groups : `LB-SG`, `Web-SG`, `DB-SG`.

Les noms fonctionnels du projet ont ete conserves, mais les valeurs reelles sensibles ou liees a un environnement particulier ne sont pas committees.

## Structure du depot

```text
.
|-- app/
|   |-- SamplePage.php
|   `-- db_config.php
|-- docs/
|   `-- architecture.md
|-- infra/
|   |-- main.tf
|   |-- outputs.tf
|   |-- terraform.tfvars.example
|   `-- variables.tf
|-- s3-site/
|   |-- error.html
|   |-- index.html
|   `-- photos.png
|-- scripts/
|   |-- init_repo.ps1
|   |-- install_app.sh
|   `-- user-data-web.sh
|-- sql/
|   `-- bootstrap_sample.sql
|-- .gitignore
`-- README.md
```

## Prerequis

- Un compte AWS avec les droits pour EC2, ELBv2, RDS, S3 et CloudWatch.
- Terraform `>= 1.5`.
- Git.
- Une image AMI Amazon Linux 2 valide pour `us-east-1`.
- Un key pair EC2 existant.
- Un VPC et des subnets adaptes a votre labo.
- Bash pour les scripts Linux.
- PHP CLI en option pour verifier la syntaxe localement.

## Initialiser Git

Le depot a ete prepare pour GitHub avec l'identite suivante :

- `user.name = Nawfal Taleb`
- `user.email = nawfal.taleb@gmail.com`

Commande PowerShell reutilisable :

```powershell
.\scripts\init_repo.ps1
```

Le script :

- initialise Git si necessaire ;
- force la branche principale sur `main` ;
- configure `user.name` et `user.email` ;
- ajoute ou met a jour `origin` vers `https://github.com/wifi-factory/CYB1153-Projet.git`.

## Utilisation de Terraform

1. Copier le fichier d'exemple :

```powershell
Copy-Item .\infra\terraform.tfvars.example .\infra\terraform.tfvars
```

2. Remplir les placeholders dans `infra/terraform.tfvars` :

- `vpc_id`
- `web_subnet_ids`
- `db_subnet_ids`
- `ami_id`
- `key_pair_name`
- `admin_cidr_ipv4`
- `s3_bucket_name`
- `db_password`

3. Executer Terraform :

```powershell
cd .\infra
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

## Ce que Terraform deploie

- Provider AWS dans `us-east-1`
- Security Groups `LB-SG`, `Web-SG`, `DB-SG`
- Deux EC2 `t2.micro` nommees `Web-1` et `Web-2`
- Une base RDS MySQL `tutorial-db-instance`
- Un bucket S3 de site statique
- Un Application Load Balancer `ALB-annuaire`
- Un target group `Groupe-web`
- Les regles ALB :
  - `/SamplePage.php` -> target group
  - `/index.html` -> redirection HTTP 302 vers le site statique S3
- Un dashboard CloudWatch `CYB1153-Dashboard`

## Placeholders et configuration manuelle

Le depot ne contient aucun secret reel. Avant execution reelle :

- fournir un mot de passe RDS dans `terraform.tfvars` ou via `TF_VAR_db_password` ;
- remplacer les IDs AWS placeholders par vos vraies valeurs ;
- choisir un nom de bucket S3 globalement unique ;
- ajuster la plage CIDR SSH d'administration ;
- verifier que l'AMI choisie correspond bien a Amazon Linux 2.

## Deploiement de l'application

Le deploiement standard passe par `user-data` Terraform :

- Apache et PHP sont installes automatiquement ;
- `SamplePage.php` et `db_config.php` sont copies dans `/var/www/html` ;
- un fichier local `db_settings.local.php` est genere sur chaque serveur web avec les valeurs RDS au moment du deploiement ;
- le service `httpd` est active et redemarre.

Pour une redeploiement manuel sur une instance Linux, utiliser :

```bash
sudo bash scripts/install_app.sh
```

Ou en precisant un repertoire source personnalise :

```bash
sudo bash scripts/install_app.sh /chemin/vers/app /var/www/html
```

## Fichiers du site statique S3

Le dossier `s3-site/` contient :

- `index.html` : page principale de vitrine ;
- `error.html` : page d'erreur statique ;
- `photos.png` : image reutilisee depuis les artefacts du projet.

Terraform uploade automatiquement ces fichiers dans le bucket S3.

## Application PHP

L'application dynamique :

- lit sa configuration MySQL depuis `app/db_config.php` ;
- accepte des overrides via un fichier local non versionne `db_settings.local.php` ;
- cree la table `Employees` si elle n'existe pas ;
- permet l'insertion de `Name` et `Address` ;
- affiche les enregistrements existants ;
- signale clairement si la configuration DB n'est pas complete.

## Ressources AWS impliquees

- Amazon EC2
- Amazon RDS for MySQL
- Application Load Balancer
- Amazon S3 static website hosting
- Amazon CloudWatch Dashboard
- Security Groups

## Rappel important sur les couts AWS

Ce projet peut generer des couts reels, surtout avec :

- RDS Multi-AZ ;
- instances EC2 ;
- ALB ;
- stockage S3.

Detruisez les ressources apres demonstration si vous n'en avez plus besoin :

```powershell
cd .\infra
terraform destroy
```

## Notes de securite

- Ne jamais committer `terraform.tfvars`.
- Ne jamais committer `db_settings.local.php`.
- Ne jamais committer de fichier `.pem`, mot de passe, token, endpoint sensible ou export console AWS.
- Le repo est volontairement assaini : il n'inclut pas les valeurs reelles vues dans le rapport final.

## Documentation complementaire

- Vue d'ensemble technique : [docs/architecture.md](docs/architecture.md)
