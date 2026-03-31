# Architecture cible

Ce depot suit maintenant de pres l'infrastructure AWS Academy observee dans le compte du lab, avec une priorite claire :

- redeployer la meme architecture logique ;
- limiter les ajustements manuels ;
- ne pas ajouter de services supplementaires qui augmentent les couts.

## Composants principaux

- Region : `us-east-1`
- VPC : VPC par defaut du compte AWS Academy
- Web subnets : decouverts automatiquement pour `us-east-1a` et `us-east-1b`
- Load Balancer : `ALB-annuaire`
- Target Group : `Group-web`
- Security Groups : `LB-SG`, `Web-SG`, `DB-SG`
- EC2 : `Web-1` et `Web-2`
- Type d'instance : `t2.micro`
- AMI : `ami-0c3389a4fa5bddaad`
- RDS : `tutorial-db-instance`
- Moteur : MySQL `8.4.7`
- Base initiale : `sample`
- Utilisateur principal : `tutorial_user`
- S3 : `cyb1153-annuaire-2026`
- Dashboard CloudWatch : `CYB1153-Dashboard`

## Comportement de redeploiement

Dans le meme lab AWS Academy, Terraform peut redeployer sans `terraform.tfvars` en utilisant :

- le VPC par defaut ;
- le DB subnet group par defaut ;
- le key pair `cyb1153-key` ;
- le bucket `cyb1153-annuaire-2026` ;
- un mot de passe RDS genere automatiquement si aucun override n'est fourni.

## Alignement avec l'etat reel

Les points importants verifies contre AWS sont :

- RDS en `db.t3.micro`
- `MultiAZ = true`
- retention de backup RDS = `7` jours
- redirection ALB `/index.html` vers le site S3
- transfert ALB `/SamplePage.php` vers `Group-web`
- health check du target group sur `/SamplePage.php` avec `matcher = 200`
- site statique S3 avec `index.html`, `error.html`, `photos.png`

## Ce que le depot n'ajoute pas volontairement

Pour rester fidele au lab et limiter les couts, le depot ne force pas :

- AWS Backup
- snapshots EBS
- AMI custom
- versioning S3

## Limite importante

Terraform peut recreer cette infrastructure proprement apres destruction ou reinitialisation du lab. Si les ressources portant les memes noms existent deja, il faut d'abord les supprimer ou les importer dans l'etat Terraform.
