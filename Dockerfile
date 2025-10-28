# --- Stage 1: Composer binary provider (lightweight) ---
FROM composer/composer:2-bin AS composer
# This stage only serves to copy the Composer binary into the final image.
# It avoids installing Composer globally via apt or manual setup, keeping the final image smaller and cleaner.


# --- Stage 2: Final application image using FrankenPHP ---
FROM dunglas/frankenphp:1.9-php8.3 AS app
# FrankenPHP is a modern PHP runtime built on top of Caddy.
# It allows serving Laravel directly, without an external web server like Nginx or Apache.


# --- Copy Composer binary from the previous stage ---
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
# This lets us use Composer inside the final image without installing it again.


# --- Set working directory for the application ---
WORKDIR /app
# All subsequent commands will run from the /app directory, which will hold the Laravel project.


# --- Install essential system dependencies ---
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    git \
    unzip \
    libpq-dev
# These are minimal system packages needed for Composer, Git, and PostgreSQL PDO support.


# --- Install required PHP extensions ---
RUN install-php-extensions \
    gd \
    pcntl \
    opcache \
    pdo \
    pdo_pgsql \
    pgsql \
    redis
# The install-php-extensions script (bundled with FrankenPHP) compiles and installs PHP extensions efficiently.
# - gd → image processing
# - pcntl → process control (used by some Laravel queue workers)
# - opcache → performance optimization
# - pdo, pdo_pgsql, pgsql → PostgreSQL support
# - redis → cache and queue driver


# --- Configure PHP security and session hardening ---
RUN printf "%s\n" \
    "expose_php=0" \
    "session.cookie_httponly=1" \
    "session.cookie_secure=1" \
    "session.use_strict_mode=1" \
    "upload_max_filesize=16M" \
    "post_max_size=16M" \
    > /usr/local/etc/php/conf.d/security.ini
# This disables PHP version exposure and enforces secure session and upload settings to prevent data leaks and session hijacking.

# --- Configure OPcache for optimal production performance ---
RUN printf "%s\n" \
    "opcache.enable=1" \
    "opcache.enable_cli=0" \
    "opcache.validate_timestamps=0" \
    "opcache.max_accelerated_files=20000" \
    "opcache.memory_consumption=192" \
    "opcache.interned_strings_buffer=16" \
    "opcache.jit=0" \
    > /usr/local/etc/php/conf.d/opcache.ini
# This enables OPcache and precompilation optimizations for PHP, greatly improving Laravel performance in production.


# --- Copy the Laravel application source code ---
COPY . .
# Copies the entire application into the container (including artisan, routes, app/, etc.)


# --- Allow Composer to run as root (required inside Docker) ---
ENV COMPOSER_ALLOW_SUPERUSER=1
# This prevents Composer from refusing to run under root, which is the default build-time user.


# --- Install Composer dependencies for production ---
RUN composer install --no-dev --prefer-dist --no-progress --no-interaction
# Installs only production dependencies (no development or test packages) to keep the image lean and secure.


# --- Optimize Composer autoloader ---
RUN composer dump-autoload --classmap-authoritative --no-dev --optimize
# Creates an optimized, authoritative class map for Laravel’s autoloader, improving startup and route performance.


# --- Fix file permissions and prepare writable directories ---
RUN mkdir -p storage/app/public public \
    # Set correct ownership for writable paths (Laravel requires these for cache, logs, etc.)
    && chown -R www-data:www-data storage bootstrap/cache public \
    # Set secure and functional directory/file permissions
    && find storage -type d -exec chmod 775 {} \; \
    && find storage -type f -exec chmod 664 {} \; \
    && chmod -R 775 bootstrap/cache \
    # Ensure public/storage symlink exists (for serving uploaded files)
    && ln -sfn /app/storage/app/public /app/public/storage \
    && chown -h www-data:www-data /app/public/storage
# This ensures Laravel has the proper access to runtime and storage folders while keeping security best practices.


# --- Prepare writable directories for FrankenPHP/Caddy runtime data ---
RUN mkdir -p /data/caddy \
    && chown -R www-data:www-data /data \
    && mkdir -p /config/caddy \
    && chown -R www-data:www-data /config
# Caddy and FrankenPHP may need to write temporary files or locks in these directories.


# --- Add custom runtime entrypoint ---
COPY deploy/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh
# The entrypoint script handles runtime setup: loading secrets from Docker secrets,
# rebuilding Laravel caches (config, routes, views, events), and finally starting FrankenPHP.

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# Replaces the default entrypoint so our script executes first.


# --- Drop privileges for runtime security ---
USER www-data
# Laravel and FrankenPHP will run as the non-root www-data user.
# Make sure any mounted volumes (e.g., /run/secrets) are readable by this user.
