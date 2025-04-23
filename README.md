# Intranet UAb (CI4) - Project Bootstrap

This is a project skeleton designed for developing applications for the [Universidade Aberta (UAb)](https://www.uab.pt) intranet, built on top of [CodeIgniter 4](https://codeigniter.com).

## Server Requirements

Ensure your server meets the following requirements:

- **PHP**: Version 8.1 or later with the following extensions installed and active:
    - [intl](http://php.net/manual/en/intl.requirements.php)
    - [mbstring](http://php.net/manual/en/mbstring.installation.php)
    - [zip](http://php.net/manual/en/zip.installation.php)

- Additionally, enable the following PHP extensions:
    - **json** (enabled by default)
    - [mysqlnd](http://php.net/manual/en/mysqlnd.install.php) (required for MySQL usage)
    - [libcurl](http://php.net/manual/en/curl.requirements.php) (required for the HTTP\CURLRequest library)

## Development Setup

Follow these steps to set up the project for development:

1. **Clone the repository**:
     ```bash
     git clone https://github.com/universidade-aberta/intranet.uab.pt_v4-skeleton.git intranet.uab.pt_v4
     ```

2. **Navigate to the project folder**:
     ```bash
     cd intranet.uab.pt_v4
     ```

3. **Configure environment settings**:
     - Create a copy of the `env` file and rename it to `.env`.
     - Customize the `.env` file to suit your application settings.

4. **Build the Docker containers**:
     ```bash
     docker compose build
     ```

5. **Start the Docker containers**:
     ```bash
     docker compose up
     ```

6. **Access the container shell**:
     ```bash
     docker exec -it intranet-uab-pt-v4 bash
     ```

7. **Install project dependencies**:
     ```bash
     composer install
     ```

8. **Run database migrations**:
     ```bash
     php spark migrate --all
     ```

9. **(Optional) Seed the database with example data**:
     ```bash
     php spark db:seed -n "Modules\Intranet\Bolsas\Database\Seeds\BolsasSeeder"
     php spark db:seed -n "Modules\Intranet\InventarioEquipamentos\Database\Seeds\EquipamentosSeed"
     ```

## Running Tests

To execute the test suite, follow these steps:

1. **Ensure dependencies are installed**:
     ```bash
     docker exec -it intranet-uab-pt-v4 composer install
     ```

2. **Run common tests**:
     ```bash
     docker exec -it intranet-uab-pt-v4 bash -c 'vendor/bin/phpunit'
     ```

3. **Run tests for the "Intranet" tenant**:
     ```bash
     docker exec -it intranet-uab-pt-v4 bash -c 'TENANT="Intranet" vendor/bin/phpunit'
     ```

## Running the Application (Development)

To start the application in development mode:
```bash
docker compose up
```

## Architecture Overview

This system is built on CodeIgniter 4 and tailored to meet the specific needs of Universidade Aberta. It features a multi-tenant and multi-module architecture, with modules located in the `app/modules` directory. The system leverages CodeIgniter's core functionality, custom libraries (`app/Libraries`), and themes (`app/themes`).

### Key Design Principles

- Minimal modifications to the CodeIgniter core to simplify framework upgrades.
- Customizations primarily focus on multi-tenant support, themes, and authentication.

### Features

The system includes the following features:

- **HTMX**: For modern, interactive web applications.
- **Shield**: Backend authentication.
- **CAS Authentication**: Central Authentication Service integration.
- **SAML Authentication**: Support for SAML-based authentication.
- **Database Logging**: Centralized logging for database operations.
- **Emailer**: Advanced email handling with queuing, logging, attachments, and templating.
- **Feedback Module**: Includes screen capture functionality.
- **FISI Client**: Integration with UAb's ESB.
- **Custom Forms Engine**: Advanced form handling with multi-form, multi-language, file uploads, and submission editing.
- **HTML Components**: Custom components for the back office.
- **Language Support**: Multi-language content and URL support.
- **LDAP Record**: Querying Active Directory.
- **LocalAccount**: Custom account management for external accounts.
- **TcPDF**: PDF generation with support for signatures and custom layouts.
- **TinyMCE**: Rich text editor integration.
- **Twig**: Virtual templates and logic engine.

## Demo Modules

The project includes sample modules to help you get started:

### `app/modules/Intranet/InventarioEquipamentos`

Access the module at: [http://localhost/v4/inventario-equipamentos](http://localhost/v4/inventario-equipamentos)

This module demonstrates basic routing, MVC structure, migrations, and seeding.

### `app/modules/Intranet/Bolsas`

Access the module at: [http://localhost/v4/bolsas](http://localhost/v4/bolsas)

This module serves as a more comprehensive example, showcasing:
- MVC structure
- Migrations and seeds
- Tasks and events
- Authorization (optional, see `@TODO` comments for enabling it)

Use these modules as references to bootstrap your custom modules.
