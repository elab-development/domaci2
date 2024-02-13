FROM php:7.4-apache

ARG APACHE_DOCUMENT_ROOT=/var/www/html
ENV APACHE_DOCUMENT_ROOT=${APACHE_DOCUMENT_ROOT}
ENV APP_FACULTY=fakultet

WORKDIR ${APACHE_DOCUMENT_ROOT}

COPY app ${APACHE_DOCUMENT_ROOT}/app
COPY 000-default.conf /etc/apache2/sites-available/000-default.conf

EXPOSE 80

CMD ["apache2-foreground"]
