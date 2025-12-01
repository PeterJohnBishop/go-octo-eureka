package wsservice

import (
	"log"
	"net/http"
	"sync"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

type WSEvent struct {
	Event  string `json:"event"`
	Data   string `json:"data"`
	Sender string `json:"sender"`
}

var (
	OnAnnouncement func(sender string, data string)
	OnConnect      func(sender string, data string)
	OnDisconnect   func(sender string, data string)
	upgrader       = websocket.Upgrader{
		CheckOrigin: func(r *http.Request) bool { return true },
	}
	clients   = make(map[*websocket.Conn]bool)
	clientMux sync.Mutex // protects the clients map
	broadcast = make(chan WSEvent)
)

func Init() {
	go handleBroadcastQueue()
}

func WebSocketRoutes(r *gin.Engine) {
	r.GET("/ws", func(c *gin.Context) {
		ws, err := upgrader.Upgrade(c.Writer, c.Request, nil)
		if err != nil {
			log.Println("Upgrade Error:", err)
			return
		}

		// Register new client safely
		clientMux.Lock()
		clients[ws] = true
		clientMux.Unlock()

		log.Println("Peer connected to our WS Server")

		// Ack client connection
		ws.WriteJSON(WSEvent{Event: "connected", Data: "Welcome to the server", Sender: "YourServer"})

		go readClientMessages(ws)
	})
	log.Println("ROUTE: GET /ws")

	r.GET("/ws/clients", func(c *gin.Context) {
		clientMux.Lock()
		count := len(clients)
		clientMux.Unlock()
		c.JSON(200, gin.H{"connected_clients": count})
	})
	log.Println("ROUTE: GET /ws/clients")
}

func readClientMessages(ws *websocket.Conn) {
	defer func() {
		clientMux.Lock()
		delete(clients, ws)
		clientMux.Unlock()
		ws.Close()
		log.Println("Client disconnected")

		if OnDisconnect != nil {
			OnDisconnect("Unknown/System", "Connection lost")
		}
	}()

	for {
		var msg WSEvent
		if err := ws.ReadJSON(&msg); err != nil {
			break // trigger defer
		}
		HandleIncomingEvent(msg)
	}
}

// SendMessage queues a message to be sent to all clients
func SendMessage(event WSEvent) {
	broadcast <- event
}

// handleBroadcastQueue runs in the background and processes the broadcast channel
func handleBroadcastQueue() {
	for {
		event := <-broadcast

		clientMux.Lock()
		for client := range clients {
			err := client.WriteJSON(event)
			if err != nil {
				log.Printf("Websocket error: %s", err)
				client.Close()
				delete(clients, client)
			}
		}
		clientMux.Unlock()
	}
}

// HandleIncomingEvent processes specific events received from clients
func HandleIncomingEvent(event WSEvent) {
	log.Printf("Received Event: %s from %s", event.Event, event.Sender)

	switch event.Event {
	case "CLIENT_CONNECTED":
		if OnConnect != nil {
			OnConnect(event.Sender, event.Data)
		}
	case "CLIENT_DISCONNECTED":
		if OnDisconnect != nil {
			OnDisconnect(event.Sender, event.Data)
		}
	case "ANNOUNCEMENT":
		if OnAnnouncement != nil {
			OnAnnouncement(event.Sender, event.Data)
		}
		SendMessage(event)
	}
}
