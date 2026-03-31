# Architecture cible

Ce depot modele une architecture CYB1153 simple et credible pour un projet AWS universitaire.

## Composants principaux

- Region AWS : `us-east-1`
- Security Groups : `LB-SG`, `Web-SG`, `DB-SG`
- Load Balancer : `ALB-annuaire`
- Target Group : `Groupe-web`
- Application web : PHP + Apache
- Route dynamique : `/SamplePage.php`
- Route statique : `/index.html`
- Base de donnees : RDS MySQL `tutorial-db-instance`
- Utilisateur principal : `tutorial_user`
- Base initiale : `sample`
- Dashboard CloudWatch : `CYB1153-Dashboard`

## Logique de flux

1. Le trafic HTTP arrive sur l'ALB.
2. `/SamplePage.php` est transfere vers les deux EC2 `Web-1` et `Web-2`.
3. `/index.html` est redirige vers l'endpoint website du bucket S3.
4. Les serveurs web accedent a RDS via `DB-SG`.
5. CloudWatch centralise les metriques de l'ALB, de RDS, de S3 et des EC2.

## Hypotheses de travail

- Le VPC et les subnets sont fournis par le compte AWS du labo.
- Les EC2 sont deployeees dans deux subnets web distincts.
- La base RDS utilise un DB subnet group avec au moins deux subnets.
- Les secrets ne sont jamais stockes dans Git.

## Valeurs a fournir manuellement

- `vpc_id`
- `web_subnet_ids`
- `db_subnet_ids`
- `ami_id`
- `key_pair_name`
- `admin_cidr_ipv4`
- `s3_bucket_name`
- `db_password`

## Decision de nettoyage

Le rapport final du projet contient des details d'environnement reesels (DNS, endpoint, IDs AWS, captures). Ces valeurs n'ont pas ete reprises dans ce depot afin de garder un contenu reutilisable, propre et non sensible.
