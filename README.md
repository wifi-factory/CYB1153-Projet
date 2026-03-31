# CYB1153 - Projet AWS Annuaire

Depot GitHub : [wifi-factory/CYB1153-Projet](https://github.com/wifi-factory/CYB1153-Projet)

Ce depot vise maintenant un objectif tres concret : permettre de redeployer, dans le meme compte AWS Academy, une infrastructure pratiquement identique a celle actuellement visible dans le lab, sans devoir remplir manuellement des `tfvars` avant execution.

## Etat de verification

Le depot a ete compare a l'infrastructure reelle du compte AWS Academy `533267248726` en `us-east-1`.

Les principaux points alignes avec l'etat reel sont :

- ALB `ALB-annuaire`
- target group `Group-web`
- 2 EC2 `t2.micro` dans `us-east-1a` et `us-east-1b`
- AMI `ami-0c3389a4fa5bddaad`
- key pair `cyb1153-key`
- bucket `cyb1153-annuaire-2026`
- RDS `tutorial-db-instance`
- base `sample`
- utilisateur `tutorial_user`
- CloudWatch dashboard `CYB1153-Dashboard`
- Security Groups `LB-SG`, `Web-SG`, `DB-SG`
- backup RDS automatique a 7 jours

## Important avant de lancer Terraform

Le depot est prepare pour recreer l'infrastructure dans le meme lab AWS Academy avec le minimum d'ajustements manuels, mais il ne peut pas recreer des ressources portant le meme nom si elles existent deja.

Concretement :

- si `tutorial-db-instance` existe deja, Terraform ne pourra pas le recreer ;
- si `cyb1153-annuaire-2026` existe deja, Terraform ne pourra pas recreer le bucket ;
- si `ALB-annuaire` existe deja, Terraform ne pourra pas recreer ce load balancer.

Donc pour une recreation propre sans ajustement manuel :

1. detruire d'abord l'infrastructure existante ;
2. ou repartir d'un lab reinitialise ;
3. puis lancer Terraform.

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

- AWS CLI ou session AWS deja active sur la machine
- Terraform `>= 1.5`
- Git
- acces au meme compte AWS Academy / Learner Lab

## Utilisation recommandee

Dans le lab AWS Academy actuel, aucun `terraform.tfvars` n'est requis pour redeployer la meme architecture logique. Les valeurs importantes sont deja preconfigurees dans les variables Terraform ou decouvertes automatiquement :

- VPC par defaut du compte
- subnets par defaut pour `us-east-1a` et `us-east-1b`
- DB subnet group par defaut du VPC
- key pair `cyb1153-key`
- bucket `cyb1153-annuaire-2026`
- AMI `ami-0c3389a4fa5bddaad`

Execution :

```powershell
cd .\infra
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## Overrides optionnels

Si tu veux redeployer ailleurs qu'au meme endroit, ou remplacer certaines valeurs, copie le fichier d'exemple :

```powershell
Copy-Item .\infra\terraform.tfvars.example .\infra\terraform.tfvars
```

Puis surcharge seulement ce qui change :

- `vpc_id`
- `web_subnet_ids`
- `db_subnet_group_name`
- `ami_id`
- `key_pair_name`
- `admin_cidr_ipv4`
- `s3_bucket_name`
- `db_password`

## Ce que Terraform recree

- les 3 Security Groups avec des descriptions et regles proches de l'etat reel ;
- les 2 EC2 `Web-1` et `Web-2` ;
- l'ALB `ALB-annuaire` ;
- le target group `Group-web` ;
- la regle ALB `/index.html` avec redirection HTTP 302 vers le site statique S3 ;
- la regle ALB `/SamplePage.php` vers les serveurs web ;
- la base RDS MySQL `tutorial-db-instance` ;
- le bucket S3 statique ;
- le dashboard CloudWatch avec les 4 metriques demandees.

## Limites assumees pour reduire les couts

Le compte reel n'utilise pas les mecanismes suivants, et le depot ne les ajoute pas volontairement pour eviter du cout et rester fidele au projet :

- aucun AWS Backup vault ;
- aucun snapshot EBS manuel ;
- aucune AMI custom ;
- aucun versioning S3.

La sauvegarde automatique RDS est conservee parce qu'elle existe deja dans l'infrastructure reelle et fait partie de la configuration actuelle.

## Secrets

Le depot ne committe aucun mot de passe ni token.

- si `db_password` n'est pas fourni, Terraform genere automatiquement un mot de passe aleatoire ;
- ce mot de passe est injecte dans RDS et dans les EC2 via `user_data` ;
- aucun secret n'est stocke en dur dans Git.

## Validation par rapport au lab reel

Le depot n'est pas une copie parfaite octet pour octet de chaque valeur AWS interne, mais il est maintenant beaucoup plus proche de l'etat reel qu'avant.

Les ecarts residuels inevitables a chaque recreation sont :

- nouveaux IDs AWS ;
- nouvelles IP publiques ;
- nouveaux ARNs ;
- nouveau mot de passe RDS genere si non fourni ;
- nouvelles dates de creation.

## Nettoyage

Pour limiter les couts :

```powershell
cd .\infra
terraform destroy
```
