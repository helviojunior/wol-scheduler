# WOL Scheduler para pfSense

Pacote para pfSense que agenda o envio de pacotes **Wake-on-LAN** e mantém máquinas
ligadas com um **Keep-Alive**: o pfSense pinga a máquina continuamente e, se ela parar
de responder, envia WOL a cada 30 segundos (configurável) até ela voltar.

- Daemon em C (`wolscheduler`), binário estático para FreeBSD, cross-compilado via Docker.
- Interface web integrada ao pfSense em **Services > WOL Scheduler**.
- Testado contra o código do **pfSense CE 2.7.0** (FreeBSD 14.0, PHP 8.2).

## Funcionalidades

| Recurso | Descrição |
|---|---|
| **Agendamento** | Envia o magic packet a cada *N* minutos para cada host (0 = desligado). |
| **Keep-Alive** | Ping a cada *X* s; após *N* falhas seguidas o host é marcado como `down` e recebe WOL a cada 30 s até responder. |
| **Status** | Aba com estado de cada host (up/down), último ping respondido, último WOL e contador. Atualiza a cada 10 s. |
| **Wake now** | Botão na aba Status para enviar WOL imediatamente. |
| **Logs** | Eventos vão para o syslog: **Status > System Logs > General**. |

## Estrutura

```
daemon/              Código C do daemon + Makefile
docker/Dockerfile    Cross-compilação (clang + sysroot FreeBSD 14.0) e empacotamento
pkg/files/           Arquivos do pacote, espelhando o filesystem do pfSense
  usr/local/pkg/wolscheduler.xml          Definição da GUI (campos, menu, serviço)
  usr/local/pkg/wolscheduler.inc          Validação, geração de config, controle do serviço
  usr/local/www/wolscheduler_status.php   Página de status
  usr/local/share/pfSense-pkg-wolscheduler/info.xml   Registro do pacote
  etc/inc/priv/wolscheduler.priv.inc      Privilégio de acesso à GUI
scripts/             install.sh / uninstall.sh (rodam no pfSense)
```

## 1. Compilar

Requisitos: **Docker** e **make** (Linux ou macOS, inclusive Apple Silicon).

```sh
make                  # amd64 (padrão – a maioria dos pfSense em x86)
make ARCH=arm64       # Netgate 1100 / 2100 (ARM)
make package-all      # ambos
```

Descubra a arquitetura do seu pfSense com `uname -m` no shell dele
(`amd64` → `ARCH=amd64`; `arm64` → `ARCH=arm64`).

Os artefatos ficam em `dist/`:

```
dist/pfSense-pkg-wolscheduler-1.0.0-amd64.tar.gz   pacote para instalar
dist/wolscheduler-amd64                             binário avulso (debug)
```

Na primeira execução o Docker baixa o `base.txz` do FreeBSD 14.0 (~180 MB) para montar
o sysroot; as execuções seguintes usam cache. Variáveis opcionais:

```sh
make VERSION=1.0.1                                   # versão do pacote
docker build --build-arg FREEBSD_VERSION=14.0-RELEASE ...   # outra versão do sysroot
```

O binário é linkado **estaticamente**, então não depende das bibliotecas do pfSense.

### Build nativo (apenas para testes locais)

```sh
make native
./daemon/wolscheduler -w 00:11:22:33:44:55 -b 192.168.1.255   # envia um WOL
```

## 2. Instalar no pfSense

Pré-requisito: acesso SSH habilitado (**System > Advanced > Admin Access > Enable Secure Shell**).

```sh
# Na sua máquina
scp dist/pfSense-pkg-wolscheduler-1.0.0-amd64.tar.gz admin@192.168.1.1:/tmp/

# No pfSense (ssh admin@192.168.1.1, opção 8 "Shell")
cd /tmp
tar -xzf pfSense-pkg-wolscheduler-1.0.0-amd64.tar.gz
cd pfSense-pkg-wolscheduler-1.0.0-amd64
sh install.sh
```

O `install.sh`:

1. verifica se o binário roda nessa arquitetura;
2. copia os arquivos para `/usr/local/...` e `/etc/inc/priv/`;
3. registra o pacote com `/etc/rc.packages pfSense-pkg-wolscheduler POST-INSTALL`,
   o mesmo mecanismo usado pelos pacotes oficiais (cria menu, serviço e entrada no `config.xml`).

Para **atualizar**, basta repetir o processo com o tarball novo. Os hosts cadastrados são mantidos.

## 3. Configurar

Acesse **Services > WOL Scheduler** e clique em **Add**:

| Campo | Exemplo | Observação |
|---|---|---|
| Enable | ✔ | |
| Description | PC Escritório | |
| MAC address | `00:11:22:33:44:55` | |
| Interface | LAN | O WOL vai para o broadcast da sub-rede dessa interface. |
| Broadcast override | *(vazio)* | Opcional, ex.: `192.168.1.255`. |
| UDP port | 9 | |
| Send WOL every (minutes) | 60 | `0` desliga o agendamento. |
| Keep-Alive | ✔ | |
| Host IP address | `192.168.1.50` | Obrigatório com Keep-Alive. |
| Ping interval (s) | 10 | |
| Ping timeout (s) | 2 | |
| Failures before down | 3 | Pings perdidos seguidos para considerar *down*. |
| WOL retry (s) | 30 | Intervalo de WOL enquanto estiver *down*. |

Ao salvar, o pacote gera `/usr/local/etc/wolscheduler.conf` e recarrega o daemon (SIGHUP),
sem perder o estado dos hosts. O serviço aparece em **Status > Services** como `wolscheduler`
e sobe automaticamente no boot. Ele só fica rodando se houver pelo menos um host habilitado
com agendamento ou Keep-Alive.

A aba **Status** mostra o estado em tempo real e tem o botão **Wake now**.

> **Dica:** se você usar Keep-Alive, configure no host o IP fixo (ou reserva DHCP em
> **Services > DHCP Server**) e libere ICMP Echo no firewall do sistema operacional
> (no Windows o ping vem bloqueado por padrão). Caso contrário o host sempre parecerá
> *down* e receberá WOL a cada 30 s.

## 4. Desinstalar

```sh
cd /tmp/pfSense-pkg-wolscheduler-1.0.0-amd64
sh uninstall.sh
```

Remove menu, serviço, entradas do `config.xml` e os arquivos instalados.

## Diagnóstico

```sh
pgrep -l wolscheduler
cat /usr/local/etc/wolscheduler.conf
cat /var/run/wolscheduler.status
grep wolscheduler /var/log/system.log

# Validar o arquivo de configuração
wolscheduler -t -c /usr/local/etc/wolscheduler.conf

# Rodar em primeiro plano com debug (pare o serviço antes)
/usr/local/etc/rc.d/wolscheduler.sh stop
wolscheduler -f -d

# Enviar um WOL manual
wolscheduler -w 00:11:22:33:44:55 -b 192.168.1.255 -P 9
```

### Opções do daemon

```
wolscheduler [-fd] [-c conf] [-p pidfile] [-s statusfile]
  -f  primeiro plano (log no stderr)      -d  log de debug
  -c  config  (/usr/local/etc/wolscheduler.conf)
  -p  pidfile (/var/run/wolscheduler.pid)
  -s  status  (/var/run/wolscheduler.status)
wolscheduler -t [-c conf]                 valida a configuração
wolscheduler -w MAC [-b broadcast] [-P porta]   envia um WOL e sai
wolscheduler -V                           versão
```

Sinais: `SIGHUP` recarrega a configuração; `SIGTERM` encerra.

## Limitações

- O pacote é instalado fora do repositório oficial, então **não aparece** em
  *System > Package Manager > Installed Packages* (a GUI e o serviço funcionam normalmente).
- Após um **upgrade do pfSense**, reinstale o pacote com `install.sh`. A configuração dos
  hosts fica no `config.xml` e é preservada.
- Keep-Alive suporta apenas IPv4.
- WOL só funciona na mesma rede L2 da interface escolhida (é broadcast). A placa de rede
  da máquina precisa ter WOL habilitado na BIOS/UEFI e no sistema operacional.
